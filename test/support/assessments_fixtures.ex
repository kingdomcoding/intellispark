defmodule Intellispark.AssessmentsFixtures do
  @moduledoc """
  Test fixtures for Phase 7 Assessments resources (SurveyTemplate,
  SurveyQuestion, SurveyTemplateVersion, SurveyAssignment,
  SurveyResponse). Builds on top of `StudentsFixtures.setup_world/0`.
  """

  require Ash.Query

  alias Intellispark.Assessments
  alias Intellispark.Assessments.{SurveyAssignment, SurveyQuestion, SurveyTemplate}

  def create_template!(school, attrs \\ %{}) do
    defaults = %{
      name: "Template #{System.unique_integer([:positive])}",
      description: "A test survey",
      duration_minutes: 5
    }

    SurveyTemplate
    |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs), tenant: school.id)
    |> Ash.create!(authorize?: false)
  end

  def create_question!(template, attrs \\ %{}) do
    defaults = %{
      survey_template_id: template.id,
      prompt: "Question #{System.unique_integer([:positive])}",
      position: 1,
      question_type: :short_text,
      required?: false,
      metadata: %{}
    }

    SurveyQuestion
    |> Ash.Changeset.for_create(:create, Map.merge(defaults, attrs), tenant: template.school_id)
    |> Ash.create!(authorize?: false)
  end

  def publish_template!(template, actor) do
    {:ok, published} =
      Assessments.publish_survey_template(template,
        actor: actor,
        tenant: template.school_id,
        authorize?: false
      )

    Ash.load!(published, :current_version,
      tenant: template.school_id,
      authorize?: false
    )
  end

  def assign_survey!(actor, school, student, template, _attrs \\ %{}) do
    {:ok, a} =
      Assessments.assign_survey(student.id, template.id,
        actor: actor,
        tenant: school.id,
        authorize?: false
      )

    a
  end

  def save_progress!(assignment, question, answer) do
    {answer_text, answer_values} =
      case answer do
        list when is_list(list) -> {nil, list}
        text when is_binary(text) -> {text, nil}
        nil -> {nil, nil}
      end

    {:ok, updated} =
      Assessments.save_survey_progress(assignment, question.id, answer_text, answer_values,
        tenant: assignment.school_id,
        authorize?: false
      )

    updated
  end

  def submit!(assignment) do
    {:ok, updated} =
      Assessments.submit_survey(assignment,
        tenant: assignment.school_id,
        authorize?: false
      )

    updated
  end

  def expire!(assignment) do
    {:ok, updated} =
      Assessments.expire_survey(assignment,
        tenant: assignment.school_id,
        authorize?: false
      )

    updated
  end

  def list_assignments_for_student(school, student) do
    SurveyAssignment
    |> Ash.Query.filter(student_id == ^student.id)
    |> Ash.Query.set_tenant(school.id)
    |> Ash.read!(authorize?: false)
  end
end
