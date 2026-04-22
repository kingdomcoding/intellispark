defmodule Intellispark.Flags.Oban.DailyFollowupReminderWorker do
  @moduledoc """
  Daily follow-up digest worker. Reads all Flag rows in :pending_followup
  whose followup_at is today, groups them by assignee, and sends one
  FollowupDigest email per user (not one per flag). Registered directly on
  the Oban crontab plugin in runtime config rather than through AshOban so
  the grouping-by-assignee shape lives in one place.
  """

  use Oban.Worker, queue: :notifications, max_attempts: 3

  require Ash.Query

  alias Intellispark.Accounts.EmailPreferences
  alias Intellispark.Flags.Emails.FollowupDigest
  alias Intellispark.Flags.Flag

  @impl Oban.Worker
  def perform(_job) do
    today = Date.utc_today()

    schools =
      Intellispark.Accounts.School
      |> Ash.read!(authorize?: false)

    flags =
      Enum.flat_map(schools, fn school ->
        Flag
        |> Ash.Query.filter(followup_at == ^today and status == :pending_followup)
        |> Ash.Query.load([
          :student,
          :flag_type,
          student: [:display_name],
          assignments: [:user]
        ])
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)
      end)

    flags
    |> Enum.flat_map(fn flag ->
      for assignment <- flag.assignments || [], is_nil(assignment.cleared_at) do
        {assignment.user, flag}
      end
    end)
    |> Enum.group_by(fn {user, _} -> user.id end, fn {user, flag} -> {user, flag} end)
    |> Enum.each(fn {_user_id, pairs} ->
      {user, _} = List.first(pairs)
      flags_for_user = Enum.map(pairs, fn {_u, f} -> f end)

      if EmailPreferences.opted_in?(user, "flag_followup") do
        try do
          FollowupDigest.send(user, flags_for_user)
        rescue
          _ -> :ok
        end
      end
    end)

    :ok
  end
end
