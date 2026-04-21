defmodule Intellispark.Assessments.BulkAssignTest do
  use Intellispark.DataCase, async: false
  use Oban.Testing, repo: Intellispark.Repo

  import Intellispark.AssessmentsFixtures
  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Assessments
  alias Intellispark.Assessments.Oban.DeliverSurveyInvitationWorker
  alias Intellispark.Assessments.SurveyAssignment

  setup do
    %{school: school, admin: admin, district: district} = setup_world()

    template = create_template!(school, %{name: "Bulk Tmpl"})
    create_question!(template, %{prompt: "Q1", position: 1, required?: false})
    published = publish_template!(template, admin)

    %{
      school: school,
      admin: admin,
      district: district,
      template: published
    }
  end

  describe ":assign_regardless" do
    test "10-student bulk produces 10 assignments + 10 invitation jobs",
         %{school: school, admin: admin, template: template} do
      students = for _ <- 1..10, do: create_student!(school)
      ids = Enum.map(students, & &1.id)

      {:ok, %Ash.BulkResult{records: records, errors: errs}} =
        Assessments.bulk_assign_survey(ids, template.id, :assign_regardless,
          actor: admin,
          tenant: school.id
        )

      assert length(records) == 10
      assert errs in [nil, []]
      assert all_enqueued(worker: DeliverSurveyInvitationWorker) |> length() == 10
    end

    test "creates duplicates even when students already submitted",
         %{school: school, admin: admin, template: template} do
      student = create_student!(school)
      first = assign_survey!(admin, school, student, template)
      _ = submit!(first)

      {:ok, %Ash.BulkResult{records: records}} =
        Assessments.bulk_assign_survey([student.id], template.id, :assign_regardless,
          actor: admin,
          tenant: school.id
        )

      assert length(records) == 1

      all =
        SurveyAssignment
        |> Ash.Query.filter(student_id == ^student.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(all) == 2
    end
  end

  describe ":skip_previously_submitted" do
    test "filters out students who already submitted this template",
         %{school: school, admin: admin, template: template} do
      done = create_student!(school)
      first = assign_survey!(admin, school, done, template)
      _ = submit!(first)

      fresh = create_student!(school)

      {:ok, %Ash.BulkResult{records: records}} =
        Assessments.bulk_assign_survey([done.id, fresh.id], template.id,
          :skip_previously_submitted,
          actor: admin,
          tenant: school.id
        )

      assert length(records) == 1
      assert hd(records).student_id == fresh.id
    end
  end

  describe "partial failure" do
    test "an invalid student_id surfaces in BulkResult.errors",
         %{school: school, admin: admin, template: template} do
      good = create_student!(school)
      bogus_id = Ecto.UUID.generate()

      {:ok, %Ash.BulkResult{} = result} =
        Assessments.bulk_assign_survey([good.id, bogus_id], template.id, :assign_regardless,
          actor: admin,
          tenant: school.id
        )

      assert is_list(result.errors)
      assert result.errors != []
      assert result.status in [:partial_success, :error]
    end
  end
end
