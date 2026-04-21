defmodule Intellispark.Assessments.Changes.PublishSurveyTemplate do
  @moduledoc false
  use Ash.Resource.Change

  require Ash.Query

  alias Intellispark.Assessments.{SurveyQuestion, SurveyTemplateVersion}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn cs ->
      template = cs.data

      {:ok, questions} =
        SurveyQuestion
        |> Ash.Query.filter(survey_template_id == ^template.id)
        |> Ash.Query.set_tenant(template.school_id)
        |> Ash.Query.sort(:position)
        |> Ash.read(authorize?: false)

      snapshot = %{
        "name" => template.name,
        "description" => template.description,
        "duration_minutes" => template.duration_minutes,
        "questions" =>
          Enum.map(questions, fn q ->
            %{
              "id" => q.id,
              "prompt" => q.prompt,
              "help_text" => q.help_text,
              "question_type" => Atom.to_string(q.question_type),
              "required?" => q.required?,
              "position" => q.position,
              "metadata" => q.metadata || %{}
            }
          end)
      }

      {:ok, version} =
        Ash.create(
          SurveyTemplateVersion,
          %{
            survey_template_id: template.id,
            schema: snapshot,
            published_at: DateTime.utc_now()
          },
          tenant: template.school_id,
          authorize?: false
        )

      cs
      |> Ash.Changeset.force_change_attribute(:published?, true)
      |> Ash.Changeset.force_change_attribute(:current_version_id, version.id)
    end)
  end
end
