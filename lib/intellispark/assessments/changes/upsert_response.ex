defmodule Intellispark.Assessments.Changes.UpsertResponse do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    question_id = Ash.Changeset.get_argument(changeset, :question_id)
    answer_text = Ash.Changeset.get_argument(changeset, :answer_text)
    answer_values = Ash.Changeset.get_argument(changeset, :answer_values) || []

    Ash.Changeset.after_action(changeset, fn _cs, assignment ->
      {:ok, _} =
        Ash.create(
          Intellispark.Assessments.SurveyResponse,
          %{
            survey_assignment_id: assignment.id,
            question_id: question_id,
            answer_text: answer_text,
            answer_values: answer_values
          },
          tenant: assignment.school_id,
          upsert?: true,
          upsert_identity: :unique_response_per_question,
          upsert_fields: [:answer_text, :answer_values, :answered_at, :updated_at],
          authorize?: false
        )

      {:ok, assignment}
    end)
  end
end
