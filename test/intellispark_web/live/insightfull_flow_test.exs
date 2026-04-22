defmodule IntellisparkWeb.InsightfullFlowTest do
  use IntellisparkWeb.ConnCase, async: false
  use Oban.Testing, repo: Intellispark.Repo

  import Phoenix.LiveViewTest
  import Intellispark.IndicatorsFixtures
  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Assessments
  alias Intellispark.Indicators.Dimension
  alias Intellispark.Indicators.IndicatorScore
  alias Intellispark.Indicators.Oban.ComputeIndicatorScoresWorker

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "happy path — all 4s → 13 :high rows",
       %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Happy", last_name: "Path"})
    template = insightfull_template!(school, admin)

    _ = submit_all!(admin, school, student, template, 4)

    [job] = all_enqueued(worker: ComputeIndicatorScoresWorker)
    assert :ok = perform_job(ComputeIndicatorScoresWorker, job.args)

    rows =
      IndicatorScore
      |> Ash.Query.filter(student_id == ^student.id)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)

    assert length(rows) == 13
    assert Enum.all?(rows, &(&1.level == :high))

    {:ok, _lv, html} =
      conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    for dim <- Dimension.all() do
      assert html =~ Dimension.humanize(dim)
    end

    assert html =~ "bg-indicator-high"
  end

  test "mixed path — first half of dims low, second half high",
       %{conn: _conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Mixed", last_name: "Path"})
    template = insightfull_template!(school, admin)

    {:ok, assignment} =
      Assessments.assign_survey(student.id, template.id,
        actor: admin,
        tenant: school.id,
        authorize?: false
      )

    questions =
      Intellispark.Assessments.SurveyQuestion
      |> Ash.Query.filter(survey_template_id == ^template.id)
      |> Ash.Query.sort(:position)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)

    low_dims = Dimension.all() |> Enum.take(6) |> Enum.map(&Atom.to_string/1)

    assignment =
      Enum.reduce(questions, assignment, fn q, a ->
        dim_str = q.metadata["dimension"]
        val = if dim_str in low_dims, do: "1", else: "5"

        {:ok, a2} =
          Assessments.save_survey_progress(a, q.id, val, nil,
            tenant: school.id,
            authorize?: false
          )

        a2
      end)

    {:ok, _} = Assessments.submit_survey(assignment, tenant: school.id, authorize?: false)

    [job] = all_enqueued(worker: ComputeIndicatorScoresWorker)
    assert :ok = perform_job(ComputeIndicatorScoresWorker, job.args)

    rows =
      IndicatorScore
      |> Ash.Query.filter(student_id == ^student.id)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)

    levels = Enum.map(rows, & &1.level) |> Enum.uniq() |> Enum.sort()
    assert levels == [:high, :low]
  end

  test "partial path — some dimensions unanswered → only answered dims scored",
       %{conn: _conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Partial", last_name: "Path"})
    template = insightfull_template!(school, admin)

    {:ok, assignment} =
      Assessments.assign_survey(student.id, template.id,
        actor: admin,
        tenant: school.id,
        authorize?: false
      )

    questions =
      Intellispark.Assessments.SurveyQuestion
      |> Ash.Query.filter(survey_template_id == ^template.id)
      |> Ash.Query.sort(:position)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)

    # Answer only the first ~half
    half = div(length(questions), 2)

    assignment =
      questions
      |> Enum.take(half)
      |> Enum.reduce(assignment, fn q, a ->
        {:ok, a2} =
          Assessments.save_survey_progress(a, q.id, "4", nil,
            tenant: school.id,
            authorize?: false
          )

        a2
      end)

    {:ok, _} = Assessments.submit_survey(assignment, tenant: school.id, authorize?: false)

    [job] = all_enqueued(worker: ComputeIndicatorScoresWorker)
    assert :ok = perform_job(ComputeIndicatorScoresWorker, job.args)

    rows =
      IndicatorScore
      |> Ash.Query.filter(student_id == ^student.id)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)

    assert length(rows) > 0
    assert length(rows) < 13
  end
end
