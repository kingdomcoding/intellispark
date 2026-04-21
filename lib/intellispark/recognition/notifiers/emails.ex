defmodule Intellispark.Recognition.Notifiers.Emails do
  @moduledoc """
  Ash notifier subscribing to HighFive create events. Fleshed out in
  Phase I — for Phase E it only needs to compile so the HighFive
  resource can `use Intellispark.Resource, notifiers: [...]`.
  """

  use Ash.Notifier

  @impl true
  def notify(_), do: :ok
end
