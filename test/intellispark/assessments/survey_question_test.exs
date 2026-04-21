defmodule Intellispark.Assessments.SurveyQuestionTest do
  use Intellispark.DataCase, async: false

  import Intellispark.AssessmentsFixtures
  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Assessments
  alias Intellispark.Assessments.SurveyQuestion

  setup do: setup_world()

  describe "question_type round-trip" do
    test "all five types persist + reload", %{school: school} do
      template = create_template!(school, %{name: "Types Tmpl"})

      types = [:short_text, :long_text, :single_choice, :multi_choice, :likert_5]

      for {type, idx} <- Enum.with_index(types, 1) do
        q = create_question!(template, %{prompt: "Q#{idx}", position: idx, question_type: type})
        assert q.question_type == type
      end

      questions =
        SurveyQuestion
        |> Ash.Query.filter(survey_template_id == ^template.id)
        |> Ash.Query.sort(:position)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert Enum.map(questions, & &1.question_type) == types
    end

    test ":single_choice metadata round-trips", %{school: school} do
      template = create_template!(school, %{name: "Meta Tmpl"})
      options = ["Red", "Green", "Blue"]

      q =
        create_question!(template, %{
          prompt: "Pick a color",
          position: 1,
          question_type: :single_choice,
          metadata: %{options: options}
        })

      reloaded = Ash.get!(SurveyQuestion, q.id, tenant: school.id, authorize?: false)
      assert reloaded.metadata["options"] == options
    end
  end

  describe "tenant isolation" do
    test "questions in school A invisible from school B",
         %{district: district, school: school} do
      other_school = add_second_school!(district, "Other Q", "oq")
      template = create_template!(school, %{name: "Iso Q"})
      _q = create_question!(template, %{prompt: "Hidden"})

      result =
        SurveyQuestion
        |> Ash.Query.filter(prompt == "Hidden")
        |> Ash.Query.set_tenant(other_school.id)
        |> Ash.read!(authorize?: false)

      assert result == []
    end
  end

  describe "ordering" do
    test "sorts by position ascending", %{school: school} do
      template = create_template!(school, %{name: "Order Tmpl"})
      create_question!(template, %{prompt: "Third", position: 3})
      create_question!(template, %{prompt: "First", position: 1})
      create_question!(template, %{prompt: "Second", position: 2})

      questions =
        SurveyQuestion
        |> Ash.Query.filter(survey_template_id == ^template.id)
        |> Ash.Query.sort(:position)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert Enum.map(questions, & &1.prompt) == ["First", "Second", "Third"]
    end
  end

  describe "required?" do
    test "defaults false; can be set true", %{school: school} do
      template = create_template!(school, %{name: "Required Tmpl"})
      q1 = create_question!(template, %{prompt: "Optional"})
      q2 = create_question!(template, %{prompt: "Mandatory", position: 2, required?: true})

      assert q1.required? == false
      assert q2.required? == true
    end
  end

  describe "update" do
    test "writes a paper-trail Version row", %{school: school, admin: admin} do
      template = create_template!(school, %{name: "Audit Q"})
      q = create_question!(template, %{prompt: "Old prompt"})

      {:ok, _} =
        Assessments.update_survey_question(q, %{prompt: "New prompt"},
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      versions =
        SurveyQuestion.Version
        |> Ash.Query.filter(version_source_id == ^q.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      action_names = Enum.map(versions, & &1.version_action_name)
      assert :create in action_names
      assert :update in action_names
    end
  end
end
