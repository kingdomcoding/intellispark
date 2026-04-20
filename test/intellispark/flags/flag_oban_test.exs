defmodule Intellispark.Flags.FlagObanTest do
  use Intellispark.DataCase, async: false
  use Oban.Testing, repo: Intellispark.Repo

  import Intellispark.StudentsFixtures
  import Intellispark.FlagsFixtures

  require Ash.Query

  alias Intellispark.Flags.Oban.DailyFollowupReminderWorker

  setup do: setup_world()

  describe "daily follow-up reminder worker" do
    test "sends one digest per assignee (not one per flag)", %{school: school, admin: admin} do
      student_a = create_student!(school, %{first_name: "Daily", last_name: "A"})
      student_b = create_student!(school, %{first_name: "Daily", last_name: "B"})
      type = create_flag_type!(school, %{name: "Academic-Daily"})

      flag_a = create_flag!(admin, school, student_a, type)
      opened_a = open_flag!(flag_a, [admin.id], admin)
      _ = set_followup!(opened_a, Date.utc_today(), admin)

      flag_b = create_flag!(admin, school, student_b, type)
      opened_b = open_flag!(flag_b, [admin.id], admin)
      _ = set_followup!(opened_b, Date.utc_today(), admin)

      # Drain the FlagAssigned emails from the setup so the assertion
      # below only observes mailbox traffic from the worker itself.
      flush_mailbox()

      assert :ok = perform_job(DailyFollowupReminderWorker, %{})

      digest_emails = received_emails(~r/awaiting your follow-up/)
      assert length(digest_emails) == 1
    end

    test "skips when no pending_followup flags due today", %{school: _school} do
      flush_mailbox()
      assert :ok = perform_job(DailyFollowupReminderWorker, %{})
      assert received_emails(~r/awaiting your follow-up/) == []
    end
  end

  defp flush_mailbox do
    # Consume any queued Swoosh test emails so subsequent assertions only
    # see traffic from the worker.
    drain_mailbox(:flush, 100)
  end

  defp received_emails(subject_regex) do
    drain_mailbox(:collect, 100)
    |> Enum.filter(&(&1.subject =~ subject_regex))
  end

  defp drain_mailbox(mode, remaining) when remaining > 0 do
    receive do
      {:email, email} ->
        if mode == :flush do
          drain_mailbox(:flush, remaining - 1)
        else
          [email | drain_mailbox(:collect, remaining - 1)]
        end
    after
      10 -> []
    end
  end

  defp drain_mailbox(_mode, 0), do: []
end
