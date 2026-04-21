defmodule Intellispark.Assessments.SurveyAssignmentTest do
  use Intellispark.DataCase, async: false

  import Intellispark.AssessmentsFixtures
  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Assessments
  alias Intellispark.Assessments.{SurveyAssignment, SurveyResponse}

  setup %{} do
    %{school: school, admin: admin, district: district} = setup_world()
    student = create_student!(school, %{first_name: "Marcus", last_name: "Test"})
    template = create_template!(school, %{name: "Tmpl Setup"})
    q1 = create_question!(template, %{prompt: "Q1", position: 1, required?: true})
    q2 = create_question!(template, %{prompt: "Q2", position: 2, required?: false})
    published = publish_template!(template, admin)

    %{
      school: school,
      admin: admin,
      district: district,
      student: student,
      template: published,
      q1: q1,
      q2: q2
    }
  end

  describe ":assign_to_student" do
    test "stamps assigned_by + token + pins template_version_id",
         %{school: school, admin: admin, student: student, template: template} do
      a = assign_survey!(admin, school, student, template)

      assert a.assigned_by_id == admin.id
      assert a.student_id == student.id
      assert a.survey_template_id == template.id
      assert a.survey_template_version_id == template.current_version_id
      assert is_binary(a.token)
      assert String.length(a.token) == 22
      assert a.state == :assigned
    end

    test "tokens are unique across 50 assignments",
         %{school: school, admin: admin, template: template} do
      tokens =
        for _ <- 1..50 do
          student = create_student!(school)
          assign_survey!(admin, school, student, template).token
        end

      assert length(Enum.uniq(tokens)) == 50
    end

    test "rejects assignment to an unpublished template",
         %{school: school, admin: admin, student: student} do
      draft = create_template!(school, %{name: "Never published"})
      create_question!(draft, %{prompt: "X"})

      assert {:error, _} =
               Assessments.assign_survey(student.id, draft.id,
                 actor: admin,
                 tenant: school.id,
                 authorize?: false
               )
    end
  end

  describe ":save_progress" do
    test "first call transitions :assigned -> :in_progress",
         %{school: school, admin: admin, student: student, template: template, q1: q1} do
      a = assign_survey!(admin, school, student, template)
      assert a.state == :assigned

      updated = save_progress!(a, q1, "First answer")
      assert updated.state == :in_progress
    end

    test "two saves on the same question upsert (one row)",
         %{school: school, admin: admin, student: student, template: template, q1: q1} do
      a = assign_survey!(admin, school, student, template)
      a = save_progress!(a, q1, "First")
      _ = save_progress!(a, q1, "Second")

      responses =
        SurveyResponse
        |> Ash.Query.filter(survey_assignment_id == ^a.id and question_id == ^q1.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(responses) == 1
      assert hd(responses).answer_text == "Second"
    end

    test "different question_ids produce different rows",
         %{
           school: school,
           admin: admin,
           student: student,
           template: template,
           q1: q1,
           q2: q2
         } do
      a = assign_survey!(admin, school, student, template)
      a = save_progress!(a, q1, "A1")
      _ = save_progress!(a, q2, "A2")

      responses =
        SurveyResponse
        |> Ash.Query.filter(survey_assignment_id == ^a.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(responses) == 2
    end
  end

  describe ":submit" do
    test "with all required answered transitions to :submitted",
         %{school: school, admin: admin, student: student, template: template, q1: q1} do
      a = assign_survey!(admin, school, student, template)
      a = save_progress!(a, q1, "Required answer")
      submitted = submit!(a)

      assert submitted.state == :submitted
      assert submitted.submitted_at != nil
    end

    test "with required missing returns error",
         %{school: school, admin: admin, student: student, template: template} do
      a = assign_survey!(admin, school, student, template)

      assert {:error, _} =
               Assessments.submit_survey(a, tenant: school.id, authorize?: false)
    end
  end

  describe ":expire" do
    test "transitions :assigned -> :expired",
         %{school: school, admin: admin, student: student, template: template} do
      a = assign_survey!(admin, school, student, template)
      expired = expire!(a)
      assert expired.state == :expired
    end

    test "rejected from :submitted",
         %{school: school, admin: admin, student: student, template: template, q1: q1} do
      a = assign_survey!(admin, school, student, template)
      a = save_progress!(a, q1, "ok")
      submitted = submit!(a)

      assert {:error, _} =
               Assessments.expire_survey(submitted, tenant: school.id, authorize?: false)
    end
  end

  describe "paper trail" do
    test "writes Version rows on every transition",
         %{school: school, admin: admin, student: student, template: template, q1: q1} do
      a = assign_survey!(admin, school, student, template)
      a = save_progress!(a, q1, "ok")
      _ = submit!(a)

      versions =
        SurveyAssignment.Version
        |> Ash.Query.filter(version_source_id == ^a.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      action_names = versions |> Enum.map(& &1.version_action_name) |> Enum.sort()
      assert :assign_to_student in action_names
      assert :save_progress in action_names
      assert :submit in action_names
    end
  end

  describe ":by_token" do
    test "returns the assignment cross-tenant",
         %{school: school, admin: admin, student: student, template: template} do
      a = assign_survey!(admin, school, student, template)

      {:ok, found} = Assessments.get_survey_assignment_by_token(a.token, authorize?: false)
      assert found.id == a.id
    end

    test "unknown token returns NotFound",
         %{} do
      assert {:error, %Ash.Error.Invalid{errors: errs}} =
               Assessments.get_survey_assignment_by_token("does-not-exist", authorize?: false)

      assert Enum.any?(errs, &match?(%Ash.Error.Query.NotFound{}, &1))
    end
  end
end
