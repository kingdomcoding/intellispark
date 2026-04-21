defmodule Intellispark.Assessments.Notifiers.Emails do
  @moduledoc """
  Ash notifier for SurveyAssignment lifecycle events. Enqueues a
  DeliverSurveyInvitationWorker job (one per assignment) on
  `:assign_to_student` + `:bulk_assign_to_students`. A Resend outage
  should not block the LiveView — Oban retries transient failures.
  """

  use Ash.Notifier

  alias Intellispark.Assessments.Oban.DeliverSurveyInvitationWorker

  @impl true
  def notify(%Ash.Notifier.Notification{
        resource: Intellispark.Assessments.SurveyAssignment,
        action: %{name: name},
        data: assignment
      })
      when name in [:assign_to_student, :bulk_assign_to_students] do
    %{assignment_id: assignment.id, school_id: assignment.school_id}
    |> DeliverSurveyInvitationWorker.new()
    |> Oban.insert()

    :ok
  end

  def notify(_), do: :ok
end
