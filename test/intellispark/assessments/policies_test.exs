defmodule Intellispark.Assessments.PoliciesTest do
  use Intellispark.DataCase, async: false

  import Intellispark.AssessmentsFixtures
  import Intellispark.StudentsFixtures

  alias Intellispark.Accounts.{User, UserSchoolMembership}
  alias Intellispark.Assessments
  alias Intellispark.Assessments.SurveyTemplate

  setup do: setup_world()

  defp user_with_role!(school, role) do
    user =
      Ash.create!(
        User,
        %{
          email: "#{role}-#{System.unique_integer([:positive])}@sandbox.edu",
          password: "supersecret123",
          password_confirmation: "supersecret123"
        },
        action: :register_with_password,
        authorize?: false
      )

    {:ok, _} =
      Ash.create(
        UserSchoolMembership,
        %{user_id: user.id, school_id: school.id, role: role, source: :manual},
        authorize?: false
      )

    Ash.load!(user, [school_memberships: [:school]], authorize?: false)
  end

  describe "staff" do
    test "teacher can create + publish a template in their own school",
         %{school: school} do
      teacher = user_with_role!(school, :teacher)

      {:ok, t} =
        Assessments.create_survey_template("Teacher Tmpl", "desc",
          actor: teacher,
          tenant: school.id
        )

      {:ok, q} =
        Ash.create(
          Intellispark.Assessments.SurveyQuestion,
          %{survey_template_id: t.id, prompt: "Q1", position: 1, question_type: :short_text},
          actor: teacher,
          tenant: school.id
        )

      assert q.survey_template_id == t.id

      {:ok, published} =
        Assessments.publish_survey_template(t, actor: teacher, tenant: school.id)

      assert published.published? == true
    end

    test "teacher cannot publish a template in another school",
         %{district: district, school: school, admin: admin} do
      other_school = add_second_school!(district, "Pol Other", "po")
      teacher = user_with_role!(school, :teacher)

      template = create_template!(other_school, %{name: "Other Tmpl"})
      _ = create_question!(template, %{prompt: "Q1"})
      published = publish_template!(template, admin)

      reloaded =
        Ash.get!(SurveyTemplate, published.id, tenant: other_school.id, authorize?: false)

      assert {:error, _} =
               Assessments.publish_survey_template(reloaded,
                 actor: teacher,
                 tenant: other_school.id
               )
    end
  end

  describe "unauthenticated student-facing actions" do
    test ":by_token returns the row for the public LiveView path",
         %{school: school, admin: admin} do
      student = create_student!(school)
      template = create_template!(school, %{name: "Anon Tmpl"})
      _ = create_question!(template, %{prompt: "Q1", required?: false})
      published = publish_template!(template, admin)
      a = assign_survey!(admin, school, student, published)

      assert {:ok, found} =
               Assessments.get_survey_assignment_by_token(a.token,
                 actor: nil,
                 authorize?: false
               )

      assert found.id == a.id
    end

    test ":save_progress succeeds without an actor",
         %{school: school, admin: admin} do
      student = create_student!(school)
      template = create_template!(school, %{name: "Anon Save"})
      q = create_question!(template, %{prompt: "Q1", required?: false})
      published = publish_template!(template, admin)
      a = assign_survey!(admin, school, student, published)

      assert {:ok, updated} =
               Assessments.save_survey_progress(a, q.id, "anon answer", nil,
                 actor: nil,
                 tenant: school.id
               )

      assert updated.state == :in_progress
    end

    test ":submit succeeds without an actor when required answered",
         %{school: school, admin: admin} do
      student = create_student!(school)
      template = create_template!(school, %{name: "Anon Submit"})
      q = create_question!(template, %{prompt: "Q1", required?: true})
      published = publish_template!(template, admin)
      a = assign_survey!(admin, school, student, published)
      a = save_progress!(a, q, "answer")

      assert {:ok, submitted} =
               Assessments.submit_survey(a, actor: nil, tenant: school.id)

      assert submitted.state == :submitted
    end
  end
end
