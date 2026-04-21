defmodule Intellispark.Assessments.Changes.ValidateRequiredResponses do
  @moduledoc false
  use Ash.Resource.Change

  require Ash.Query

  alias Intellispark.Assessments.{SurveyResponse, SurveyTemplateVersion}

  @impl true
  def change(changeset, _opts, _context) do
    assignment = changeset.data

    case Ash.get(SurveyTemplateVersion, assignment.survey_template_version_id,
           tenant: assignment.school_id,
           authorize?: false
         ) do
      {:ok, %{schema: schema}} ->
        required_ids =
          (schema["questions"] || [])
          |> Enum.filter(& &1["required?"])
          |> Enum.map(& &1["id"])

        {:ok, responses} =
          SurveyResponse
          |> Ash.Query.filter(survey_assignment_id == ^assignment.id)
          |> Ash.Query.set_tenant(assignment.school_id)
          |> Ash.read(authorize?: false)

        answered_ids =
          responses
          |> Enum.filter(&has_answer?/1)
          |> Enum.map(& &1.question_id)

        missing = required_ids -- answered_ids

        if missing == [] do
          changeset
        else
          Ash.Changeset.add_error(changeset,
            field: :responses,
            message: "#{length(missing)} required question(s) unanswered"
          )
        end

      _ ->
        Ash.Changeset.add_error(changeset,
          field: :survey_template_version_id,
          message: "pinned version not found"
        )
    end
  end

  defp has_answer?(%{answer_text: t}) when is_binary(t) and t != "", do: true
  defp has_answer?(%{answer_values: vs}) when is_list(vs) and vs != [], do: true
  defp has_answer?(_), do: false
end
