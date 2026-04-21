defmodule Intellispark.Assessments.SurveyResponseTest do
  use Intellispark.DataCase, async: false

  import Intellispark.AssessmentsFixtures
  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Assessments
  alias Intellispark.Assessments.SurveyResponse

  setup do
    %{school: school, admin: admin, district: district} = setup_world()
    student = create_student!(school)
    template = create_template!(school, %{name: "Resp Tmpl"})
    q1 = create_question!(template, %{prompt: "Q1", position: 1, required?: true})
    q2 = create_question!(template, %{prompt: "Q2", position: 2})
    published = publish_template!(template, admin)

    a = assign_survey!(admin, school, student, published)

    %{
      school: school,
      admin: admin,
      district: district,
      student: student,
      template: published,
      assignment: a,
      q1: q1,
      q2: q2
    }
  end

  describe "upsert identity" do
    test "same (assignment, question) updates the existing row",
         %{school: school, assignment: a, q1: q1} do
      a = save_progress!(a, q1, "First")
      _ = save_progress!(a, q1, "Updated")

      rows =
        SurveyResponse
        |> Ash.Query.filter(survey_assignment_id == ^a.id and question_id == ^q1.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(rows) == 1
      assert hd(rows).answer_text == "Updated"
    end
  end

  describe "two questions" do
    test "produce two rows on the same assignment",
         %{school: school, assignment: a, q1: q1, q2: q2} do
      a = save_progress!(a, q1, "A1")
      _ = save_progress!(a, q2, "A2")

      rows =
        SurveyResponse
        |> Ash.Query.filter(survey_assignment_id == ^a.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(rows) == 2
    end
  end

  describe "blank validation on submit" do
    test "answer_values: [] + answer_text: nil counts as missing",
         %{school: school, assignment: a, q1: q1} do
      _ = save_progress!(a, q1, [])

      assert {:error, _} =
               Assessments.submit_survey(a, tenant: school.id, authorize?: false)
    end
  end

  describe "tenant isolation" do
    test "responses in school A invisible from school B",
         %{district: district, assignment: a, q1: q1} do
      other_school = add_second_school!(district, "Other Resp", "or")
      _ = save_progress!(a, q1, "Hidden answer")

      result =
        SurveyResponse
        |> Ash.Query.filter(survey_assignment_id == ^a.id)
        |> Ash.Query.set_tenant(other_school.id)
        |> Ash.read!(authorize?: false)

      assert result == []
    end
  end
end
