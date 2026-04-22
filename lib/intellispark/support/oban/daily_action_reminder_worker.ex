defmodule Intellispark.Support.Oban.DailyActionReminderWorker do
  @moduledoc """
  Daily action digest worker. Reads all Action rows in :pending whose
  due_on is today or earlier, groups them by assignee, and sends one
  ActionDigest email per user.
  """

  use Oban.Worker, queue: :notifications, max_attempts: 3

  require Ash.Query

  alias Intellispark.Support.Action
  alias Intellispark.Support.Emails.ActionDigest

  @impl Oban.Worker
  def perform(_job) do
    today = Date.utc_today()

    schools =
      Intellispark.Accounts.School
      |> Ash.read!(authorize?: false)

    actions =
      Enum.flat_map(schools, fn school ->
        Action
        |> Ash.Query.filter(status == :pending and not is_nil(due_on) and due_on <= ^today)
        |> Ash.Query.load([
          :assignee,
          :student,
          student: [:display_name]
        ])
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)
      end)

    actions
    |> Enum.group_by(& &1.assignee_id)
    |> Enum.each(fn {_user_id, actions_for_user} ->
      user = List.first(actions_for_user).assignee

      if Intellispark.Accounts.EmailPreferences.opted_in?(user, "action_due") do
        try do
          ActionDigest.send(user, actions_for_user)
        rescue
          _ -> :ok
        end
      end
    end)

    :ok
  end
end
