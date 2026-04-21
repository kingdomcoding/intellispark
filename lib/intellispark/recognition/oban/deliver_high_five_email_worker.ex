defmodule Intellispark.Recognition.Oban.DeliverHighFiveEmailWorker do
  @moduledoc """
  Oban worker that hydrates a HighFive by id, loads student + sender
  display fields, and dispatches the Swoosh notification email. Called
  via the Recognition.Notifiers.Emails notifier on `:send_to_student`
  and `:bulk_send_to_students` actions.
  """

  use Oban.Worker, queue: :emails, max_attempts: 5

  alias Intellispark.Recognition
  alias Intellispark.Recognition.Emails.HighFiveNotification

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"high_five_id" => id}}) do
    case Recognition.get_high_five(id, authorize?: false) do
      {:ok, high_five} ->
        hydrated =
          Ash.load!(
            high_five,
            [:student, :sent_by, student: [:display_name]],
            authorize?: false
          )

        try do
          HighFiveNotification.send(hydrated)
          :ok
        rescue
          err -> {:error, err}
        end

      _ ->
        {:error, :not_found}
    end
  end
end
