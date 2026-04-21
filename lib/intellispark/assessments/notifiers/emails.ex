defmodule Intellispark.Assessments.Notifiers.Emails do
  @moduledoc """
  Ash notifier for SurveyAssignment lifecycle events. Phase F-stub;
  fleshed out in Phase I to enqueue Oban email delivery jobs.
  """

  use Ash.Notifier

  @impl true
  def notify(_), do: :ok
end
