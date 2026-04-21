defmodule Intellispark.Assessments.ObanTest do
  use Intellispark.DataCase, async: false
  use Oban.Testing, repo: Intellispark.Repo

  import Ecto.Query

  import Intellispark.AssessmentsFixtures
  import Intellispark.StudentsFixtures

  alias Intellispark.Assessments.Oban.{
    DailySurveyReminderScanner,
    DeliverSurveyReminderWorker
  }

  alias Intellispark.Assessments.SurveyAssignment

  setup do
    %{school: school, admin: admin, district: district} = setup_world()
    template = create_template!(school, %{name: "Oban Tmpl"})
    create_question!(template, %{prompt: "Q1", required?: false})
    published = publish_template!(template, admin)

    %{
      school: school,
      admin: admin,
      district: district,
      template: published
    }
  end

  defp backdate_assigned_at(%SurveyAssignment{id: id}, days_ago) do
    ts = DateTime.add(DateTime.utc_now(), -days_ago * 86_400, :second)

    Intellispark.Repo.update_all(
      from(sa in "survey_assignments", where: sa.id == ^Ecto.UUID.dump!(id)),
      set: [assigned_at: ts]
    )
  end

  defp expire_in_past(%SurveyAssignment{id: id}, days_ago) do
    ts = DateTime.add(DateTime.utc_now(), -days_ago * 86_400, :second)

    Intellispark.Repo.update_all(
      from(sa in "survey_assignments", where: sa.id == ^Ecto.UUID.dump!(id)),
      set: [expires_at: ts]
    )
  end

  describe "DailySurveyReminderScanner" do
    test "enqueues one reminder per due assignment + stamps last_reminded_at",
         %{school: school, admin: admin, template: template} do
      student = create_student!(school, %{email: "student@example.com"})
      a = assign_survey!(admin, school, student, template)
      backdate_assigned_at(a, 3)

      assert :ok = perform_job(DailySurveyReminderScanner, %{})

      reminder_jobs = all_enqueued(worker: DeliverSurveyReminderWorker)
      assert length(reminder_jobs) == 1

      [job] = reminder_jobs
      assert job.args["assignment_id"] == a.id
      assert job.args["school_id"] == school.id

      assert :ok = perform_job(DeliverSurveyReminderWorker, job.args)

      reloaded = Ash.get!(SurveyAssignment, a.id, tenant: school.id, authorize?: false)
      assert reloaded.last_reminded_at != nil
    end

    test "empty state produces 0 jobs", %{} do
      assert :ok = perform_job(DailySurveyReminderScanner, %{})
      assert all_enqueued(worker: DeliverSurveyReminderWorker) == []
    end
  end

  describe "expire trigger" do
    test "transitions stale :assigned to :expired",
         %{school: school, admin: admin, template: template} do
      student = create_student!(school)
      a = assign_survey!(admin, school, student, template)
      expire_in_past(a, 1)

      reloaded = Ash.get!(SurveyAssignment, a.id, tenant: school.id, authorize?: false)

      {:ok, expired} =
        Intellispark.Assessments.expire_survey(reloaded,
          tenant: school.id,
          authorize?: false
        )

      assert expired.state == :expired
    end
  end
end
