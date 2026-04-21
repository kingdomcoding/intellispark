defmodule Intellispark.Recognition.Notifiers.Emails do
  @moduledoc """
  Ash notifier subscribing to HighFive create events. Enqueues a
  DeliverHighFiveEmailWorker job (one per high 5) instead of sending
  synchronously — a Resend outage shouldn't block the LiveView.
  """

  use Ash.Notifier

  alias Intellispark.Recognition.Oban.DeliverHighFiveEmailWorker

  @impl true
  def notify(%Ash.Notifier.Notification{
        resource: Intellispark.Recognition.HighFive,
        action: %{name: name},
        data: high_five
      })
      when name in [:send_to_student, :bulk_send_to_students] do
    %{high_five_id: high_five.id, school_id: high_five.school_id}
    |> DeliverHighFiveEmailWorker.new()
    |> Oban.insert()

    :ok
  end

  def notify(_), do: :ok
end
