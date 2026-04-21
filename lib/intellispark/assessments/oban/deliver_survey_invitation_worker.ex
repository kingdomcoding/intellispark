defmodule Intellispark.Assessments.Oban.DeliverSurveyInvitationWorker do
  @moduledoc """
  Oban worker that hydrates a SurveyAssignment + template + student,
  then dispatches `SurveyInvitation.send/1`. Called via the
  Assessments.Notifiers.Emails notifier on `:assign_to_student` and
  `:bulk_assign_to_students` actions.
  """

  use Oban.Worker, queue: :emails, max_attempts: 5

  alias Intellispark.Assessments
  alias Intellispark.Assessments.Emails.SurveyInvitation

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"assignment_id" => id, "school_id" => school_id}}) do
    case Assessments.get_survey_assignment(id, tenant: school_id, authorize?: false) do
      {:ok, assignment} ->
        hydrated =
          Ash.load!(assignment, [:student, :survey_template],
            tenant: school_id,
            authorize?: false
          )

        try do
          SurveyInvitation.send(hydrated)
          :ok
        rescue
          err -> {:error, err}
        end

      _ ->
        {:error, :not_found}
    end
  end
end
