defmodule Intellispark.Digest.WeeklyDigestWorker do
  @moduledoc """
  Cron-triggered weekly digest worker. Mondays at 7 AM UTC scans every
  staff member with `weekly_digest` opted-in, builds their digest from
  the prior 7 days of activity for students they're on the team of,
  and emails it via the existing :emails queue. Empty digests are
  skipped.
  """

  use Oban.Worker, queue: :emails, max_attempts: 3, unique: [period: 60 * 60 * 24]

  alias Intellispark.Accounts.{EmailPreferences, User, UserSchoolMembership}
  alias Intellispark.Digest.{WeeklyDigestComposer, WeeklyDigestEmail}

  @impl Oban.Worker
  def perform(_job) do
    week_starts_on = Date.utc_today() |> Date.add(-7)

    UserSchoolMembership
    |> Ash.Query.load(:user)
    |> Ash.read!(authorize?: false)
    |> Enum.each(&deliver(&1, week_starts_on))

    :ok
  end

  defp deliver(membership, week_starts_on) do
    user = membership.user

    if user_loaded?(user) and EmailPreferences.opted_in?(user, "weekly_digest") do
      digest = WeeklyDigestComposer.build(user, membership.school_id, week_starts_on)

      unless WeeklyDigestComposer.empty?(digest) do
        try do
          WeeklyDigestEmail.send(digest)
        rescue
          _ -> :ok
        end
      end
    end
  end

  defp user_loaded?(%User{}), do: true
  defp user_loaded?(_), do: false
end
