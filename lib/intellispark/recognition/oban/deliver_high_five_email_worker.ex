defmodule Intellispark.Recognition.Oban.DeliverHighFiveEmailWorker do
  @moduledoc """
  Oban worker that hydrates a HighFive by id, loads student + sender
  display fields, and dispatches the Swoosh notification email. Called
  via the Recognition.Notifiers.Emails notifier on `:send_to_student`
  and `:bulk_send_to_students` actions.
  """

  use Oban.Worker, queue: :emails, max_attempts: 5

  alias Intellispark.Accounts.EmailPreferences
  alias Intellispark.Accounts.User
  alias Intellispark.Recognition
  alias Intellispark.Recognition.Emails.HighFiveNotification

  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"high_five_id" => id, "school_id" => school_id} = args}) do
    event_kind = Map.get(args, "event_kind", "high_five_received")

    case Recognition.get_high_five(id, tenant: school_id, authorize?: false) do
      {:ok, high_five} ->
        hydrated =
          Ash.load!(
            high_five,
            [:student, :sent_by, student: [:display_name, :school]],
            tenant: school_id,
            authorize?: false
          )

        if recipient_opted_in?(hydrated.recipient_email, event_kind) do
          try do
            HighFiveNotification.send(hydrated)
            :ok
          rescue
            err -> {:error, err}
          end
        else
          :ok
        end

      _ ->
        {:error, :not_found}
    end
  end

  defp recipient_opted_in?(email, event_kind) when is_binary(email) do
    case lookup_user(email) do
      nil -> true
      user -> EmailPreferences.opted_in?(user, event_kind)
    end
  end

  defp recipient_opted_in?(_, _), do: true

  defp lookup_user(email) do
    User
    |> Ash.Query.filter(email == ^email)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, user} -> user
      _ -> nil
    end
  end
end
