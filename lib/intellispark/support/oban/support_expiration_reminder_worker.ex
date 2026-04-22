defmodule Intellispark.Support.Oban.SupportExpirationReminderWorker do
  @moduledoc """
  Daily support-expiration worker. Picks up :in_progress Supports whose
  ends_at falls within the next 3 days, groups them by provider_staff,
  and sends one SupportExpiring digest email per provider.
  """

  use Oban.Worker, queue: :notifications, max_attempts: 3

  require Ash.Query

  alias Intellispark.Support.Emails.SupportExpiring
  alias Intellispark.Support.Support

  @impl Oban.Worker
  def perform(_job) do
    today = Date.utc_today()
    window_end = Date.add(today, 3)

    schools =
      Intellispark.Accounts.School
      |> Ash.read!(authorize?: false)

    supports =
      Enum.flat_map(schools, fn school ->
        Support
        |> Ash.Query.filter(
          status == :in_progress and
            not is_nil(ends_at) and
            ends_at >= ^today and
            ends_at <= ^window_end and
            not is_nil(provider_staff_id)
        )
        |> Ash.Query.load([
          :provider_staff,
          :student,
          student: [:display_name]
        ])
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)
      end)

    supports
    |> Enum.group_by(& &1.provider_staff_id)
    |> Enum.each(fn {_user_id, supports_for_user} ->
      user = List.first(supports_for_user).provider_staff

      if Intellispark.Accounts.EmailPreferences.opted_in?(user, "action_due") do
        try do
          SupportExpiring.send(user, supports_for_user)
        rescue
          _ -> :ok
        end
      end
    end)

    :ok
  end
end
