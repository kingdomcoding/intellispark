defmodule Intellispark.Assessments.Oban.DeliverSurveyReminderWorker do
  @moduledoc """
  Oban worker that sends a survey reminder email + stamps
  `last_reminded_at` on the assignment so the scanner doesn't
  re-enqueue too often.
  """

  use Oban.Worker, queue: :emails, max_attempts: 5

  alias Intellispark.Assessments
  alias Intellispark.Assessments.Emails.SurveyReminder

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
          SurveyReminder.send(hydrated)

          {:ok, _} =
            Assessments.touch_last_reminded(hydrated,
              tenant: school_id,
              authorize?: false
            )

          :ok
        rescue
          err -> {:error, err}
        end

      _ ->
        {:error, :not_found}
    end
  end
end
