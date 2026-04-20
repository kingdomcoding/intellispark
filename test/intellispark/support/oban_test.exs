defmodule Intellispark.Support.ObanTest do
  use Intellispark.DataCase, async: false
  use Oban.Testing, repo: Intellispark.Repo

  import Intellispark.StudentsFixtures
  import Intellispark.SupportFixtures

  alias Intellispark.Support.Oban.DailyActionReminderWorker
  alias Intellispark.Support.Oban.SupportExpirationReminderWorker

  setup do: setup_world()

  describe "DailyActionReminderWorker" do
    test "sends one digest per assignee (not one per action)", %{school: school, admin: admin} do
      student_a = create_student!(school, %{first_name: "Due", last_name: "A"})
      student_b = create_student!(school, %{first_name: "Due", last_name: "B"})

      _ =
        create_action!(admin, school, student_a, admin, %{
          description: "call home",
          due_on: Date.utc_today()
        })

      _ =
        create_action!(admin, school, student_b, admin, %{
          description: "schedule meet",
          due_on: Date.add(Date.utc_today(), -1)
        })

      flush_mailbox()

      assert :ok = perform_job(DailyActionReminderWorker, %{})

      digests = received_emails(~r/action\(s\) due today or overdue/)
      assert length(digests) == 1
    end

    test "no emails when nothing matches", %{school: _school} do
      flush_mailbox()
      assert :ok = perform_job(DailyActionReminderWorker, %{})
      assert received_emails(~r/action\(s\) due today or overdue/) == []
    end
  end

  describe "SupportExpirationReminderWorker" do
    test "picks supports ending within 3 days with a provider", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Exp", last_name: "Soon"})

      support =
        create_support!(admin, school, student, %{
          provider_staff_id: admin.id,
          starts_at: Date.utc_today(),
          ends_at: Date.add(Date.utc_today(), 2)
        })

      _ = accept_support!(support, admin)

      flush_mailbox()

      assert :ok = perform_job(SupportExpirationReminderWorker, %{})

      digests = received_emails(~r/support\(s\) ending this week/)
      assert length(digests) == 1
    end

    test "skips supports outside 3-day window", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "Exp", last_name: "Later"})

      support =
        create_support!(admin, school, student, %{
          provider_staff_id: admin.id,
          starts_at: Date.utc_today(),
          ends_at: Date.add(Date.utc_today(), 30)
        })

      _ = accept_support!(support, admin)

      flush_mailbox()

      assert :ok = perform_job(SupportExpirationReminderWorker, %{})
      assert received_emails(~r/support\(s\) ending this week/) == []
    end
  end

  defp flush_mailbox, do: drain_mailbox(:flush, 100)

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
