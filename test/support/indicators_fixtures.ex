defmodule Intellispark.IndicatorsFixtures do
  @moduledoc """
  Test fixtures for Phase 8 Indicators resources (IndicatorScore) +
  Insightfull survey scoring. Builds on Assessments + Students
  fixtures.
  """

  require Ash.Query

  alias Intellispark.Assessments
  alias Intellispark.Indicators
  alias Intellispark.Indicators.{Dimension, IndicatorScore}

  def insightfull_template!(school, actor, opts \\ []) do
    items_per_dimension = Keyword.get(opts, :items_per_dimension, 2)

    {:ok, tmpl} =
      Assessments.create_survey_template(
        "Insightfull-#{System.unique_integer([:positive])}",
        "Fixture Insightfull",
        actor: actor,
        tenant: school.id,
        authorize?: false
      )

    questions =
      Dimension.all()
      |> Enum.flat_map(fn dim ->
        for i <- 1..items_per_dimension do
          {dim, i, "Q-#{dim}-#{i}"}
        end
      end)

    questions
    |> Enum.with_index(1)
    |> Enum.each(fn {{dim, _i, prompt}, pos} ->
      Assessments.create_survey_question(
        tmpl.id,
        pos,
        prompt,
        :dimension_rating,
        %{
          required?: false,
          metadata: %{
            "dimension" => Atom.to_string(dim),
            "scale_labels" => ["Never", "Rarely", "Sometimes", "Often", "Always"]
          }
        },
        actor: actor,
        tenant: school.id,
        authorize?: false
      )
    end)

    {:ok, published} =
      Assessments.publish_survey_template(tmpl, actor: actor, tenant: school.id, authorize?: false)

    published
  end

  def submit_all!(actor, school, student, template, answer_value) do
    {:ok, assignment} =
      Assessments.assign_survey(student.id, template.id,
        actor: actor,
        tenant: school.id,
        authorize?: false
      )

    questions =
      Intellispark.Assessments.SurveyQuestion
      |> Ash.Query.filter(survey_template_id == ^template.id)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)

    assignment =
      Enum.reduce(questions, assignment, fn q, a ->
        {:ok, a2} =
          Assessments.save_survey_progress(
            a,
            q.id,
            Integer.to_string(answer_value),
            nil,
            tenant: school.id,
            authorize?: false
          )

        a2
      end)

    {:ok, submitted} =
      Assessments.submit_survey(assignment, tenant: school.id, authorize?: false)

    submitted
  end

  def score!(assignment) do
    :ok = Indicators.compute_for_assignment(assignment.id, assignment.school_id)

    IndicatorScore
    |> Ash.Query.filter(student_id == ^assignment.student_id)
    |> Ash.Query.set_tenant(assignment.school_id)
    |> Ash.read!(authorize?: false)
  end
end
