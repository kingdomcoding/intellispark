defmodule Intellispark.Indicators.ObanTest do
  use Intellispark.DataCase, async: false
  use Oban.Testing, repo: Intellispark.Repo

  import Intellispark.AssessmentsFixtures
  import Intellispark.IndicatorsFixtures
  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Assessments
  alias Intellispark.Indicators.IndicatorScore
  alias Intellispark.Indicators.Oban.ComputeIndicatorScoresWorker

  setup do
    %{school: school, admin: admin} = setup_world()
    student = create_student!(school)

    %{
      school: school,
      admin: admin,
      student: student
    }
  end

  describe "ComputeIndicatorScoresWorker" do
    test "on Insightfull submission produces 13 IndicatorScore rows when all dims answered",
         %{school: school, admin: admin, student: student} do
      template = insightfull_template!(school, admin)
      assignment = submit_all!(admin, school, student, template, 4)

      assert :ok =
               perform_job(ComputeIndicatorScoresWorker, %{
                 "assignment_id" => assignment.id,
                 "school_id" => school.id
               })

      rows =
        IndicatorScore
        |> Ash.Query.filter(student_id == ^student.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(rows) == 13
      assert Enum.all?(rows, &(&1.level == :high))
    end

    test "on non-Insightfull template (no :dimension_rating questions) produces zero rows",
         %{school: school, admin: admin, student: student} do
      tmpl = create_template!(school, %{name: "Non-Ins-#{System.unique_integer([:positive])}"})
      create_question!(tmpl, %{prompt: "Q", position: 1, question_type: :short_text})

      {:ok, published} =
        Assessments.publish_survey_template(tmpl,
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      {:ok, assignment} =
        Assessments.assign_survey(student.id, published.id,
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      {:ok, _} =
        Assessments.save_survey_progress(
          assignment,
          hd_question_id(published, school.id),
          "anything",
          nil,
          tenant: school.id,
          authorize?: false
        )

      {:ok, submitted} =
        Assessments.submit_survey(assignment, tenant: school.id, authorize?: false)

      assert :ok =
               perform_job(ComputeIndicatorScoresWorker, %{
                 "assignment_id" => submitted.id,
                 "school_id" => school.id
               })

      rows =
        IndicatorScore
        |> Ash.Query.filter(student_id == ^student.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert rows == []
    end
  end

  defp hd_question_id(template, school_id) do
    Intellispark.Assessments.SurveyQuestion
    |> Ash.Query.filter(survey_template_id == ^template.id)
    |> Ash.Query.set_tenant(school_id)
    |> Ash.read!(authorize?: false)
    |> hd()
    |> Map.fetch!(:id)
  end
end
