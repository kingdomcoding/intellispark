defmodule Intellispark.Assessments.SurveyTemplateTest do
  use Intellispark.DataCase, async: false

  import Intellispark.AssessmentsFixtures
  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Assessments
  alias Intellispark.Assessments.{SurveyTemplate, SurveyTemplateVersion}

  setup do: setup_world()

  describe ":create" do
    test "lands as draft (published? false, current_version_id nil)", %{school: school} do
      template = create_template!(school, %{name: "Draft Template"})

      assert template.published? == false
      assert template.current_version_id == nil
      assert template.school_id == school.id
    end
  end

  describe ":publish" do
    test "creates a SurveyTemplateVersion + flips published? + pins current_version_id",
         %{school: school, admin: admin} do
      template = create_template!(school, %{name: "Pub Template"})
      _q = create_question!(template, %{prompt: "Q1", position: 1})

      published = publish_template!(template, admin)

      assert published.published? == true
      assert published.current_version_id != nil
      assert %SurveyTemplateVersion{} = published.current_version
      assert published.current_version.survey_template_id == template.id
    end

    test "re-publish creates a second version", %{school: school, admin: admin} do
      template = create_template!(school, %{name: "ReVer Template"})
      create_question!(template, %{prompt: "Q1", position: 1})

      first = publish_template!(template, admin)
      first_version_id = first.current_version_id

      {:ok, _} =
        Assessments.update_survey_template(first, %{description: "edited"},
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      reloaded = Ash.get!(SurveyTemplate, template.id, tenant: school.id, authorize?: false)
      republished = publish_template!(reloaded, admin)

      assert republished.current_version_id != first_version_id

      versions =
        SurveyTemplateVersion
        |> Ash.Query.filter(survey_template_id == ^template.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(versions) == 2
    end
  end

  describe ":unpublish" do
    test "flips published? but leaves current_version_id alone",
         %{school: school, admin: admin} do
      template = create_template!(school, %{name: "Unpub Template"})
      create_question!(template, %{prompt: "Q1"})
      published = publish_template!(template, admin)
      pinned_id = published.current_version_id

      {:ok, unpublished} =
        Assessments.unpublish_survey_template(published,
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      assert unpublished.published? == false
      assert unpublished.current_version_id == pinned_id
    end
  end

  describe "paper trail" do
    test "writes a Version row on create + update + publish",
         %{school: school, admin: admin} do
      template = create_template!(school, %{name: "Audited"})
      create_question!(template, %{prompt: "Q1"})

      {:ok, updated} =
        Assessments.update_survey_template(template, %{description: "new"},
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      _ = publish_template!(updated, admin)

      versions =
        SurveyTemplate.Version
        |> Ash.Query.filter(version_source_id == ^template.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      action_names = versions |> Enum.map(& &1.version_action_name) |> Enum.sort()
      assert :create in action_names
      assert :update in action_names
      assert :publish in action_names
    end
  end

  describe "tenant isolation" do
    test "templates in school A are invisible from school B",
         %{district: district, school: school} do
      other_school = add_second_school!(district, "Other School", "other-iso")
      _t = create_template!(school, %{name: "Iso Template"})

      result =
        SurveyTemplate
        |> Ash.Query.filter(name == "Iso Template")
        |> Ash.Query.set_tenant(other_school.id)
        |> Ash.read!(authorize?: false)

      assert result == []
    end
  end

  describe "unique_name_per_school identity" do
    test "rejects duplicate (school, name)", %{school: school} do
      _t1 = create_template!(school, %{name: "Dup"})

      assert_raise Ash.Error.Invalid, fn ->
        create_template!(school, %{name: "Dup"})
      end
    end
  end
end
