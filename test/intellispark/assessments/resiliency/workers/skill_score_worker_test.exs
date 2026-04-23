defmodule Intellispark.Assessments.Resiliency.Workers.SkillScoreWorkerTest do
  use Intellispark.DataCase

  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Assessments
  alias Intellispark.Assessments.Resiliency.{QuestionBank, SkillScore}
  alias Intellispark.Assessments.Resiliency.Workers.SkillScoreWorker

  setup do
    ctx = setup_world()
    _ = set_school_tier!(ctx.school, :pro)
    school = Ash.load!(ctx.school, [:subscription], authorize?: false)
    admin = Map.put(ctx.admin, :current_school, school)
    ctx |> Map.put(:school, school) |> Map.put(:admin, admin)
  end

  defp assign_18_responses(admin, school, student, value) do
    {:ok, a} =
      Assessments.assign_resiliency(student.id, :grades_9_12,
        actor: admin,
        tenant: school.id
      )

    for q <- QuestionBank.questions_for(:grades_9_12) do
      {:ok, _} =
        Assessments.upsert_resiliency_response(
          a.id,
          q.id,
          value,
          tenant: school.id,
          authorize?: false
        )
    end

    a
  end

  defp run(assessment, school) do
    SkillScoreWorker.perform(%Oban.Job{
      args: %{"assessment_id" => assessment.id, "tenant" => school.id}
    })
  end

  defp scores_for(student, school) do
    SkillScore
    |> Ash.Query.filter(student_id == ^student.id)
    |> Ash.Query.set_tenant(school.id)
    |> Ash.read!(authorize?: false)
  end

  test "18 responses at value 4 produce 6 :high scores", %{admin: admin, school: school} do
    student = create_student!(school, %{first_name: "Wh", last_name: "High"})
    a = assign_18_responses(admin, school, student, 4)

    assert :ok = run(a, school)

    scores = scores_for(student, school)
    assert length(scores) == 6
    assert Enum.all?(scores, &(&1.level == :high))
    assert Enum.all?(scores, &(&1.score_value == 4.0))
    assert Enum.all?(scores, &(&1.answered_count == 3))
  end

  test "mixed responses produce per-skill bands correctly", %{admin: admin, school: school} do
    student = create_student!(school, %{first_name: "Mix", last_name: "Band"})

    {:ok, a} =
      Assessments.assign_resiliency(student.id, :grades_9_12,
        actor: admin,
        tenant: school.id
      )

    for q <- QuestionBank.questions_for(:grades_9_12) do
      value =
        case q.skill do
          :confidence -> 5
          :persistence -> 3
          _ -> 1
        end

      {:ok, _} =
        Assessments.upsert_resiliency_response(
          a.id,
          q.id,
          value,
          tenant: school.id,
          authorize?: false
        )
    end

    assert :ok = run(a, school)

    by_skill = scores_for(student, school) |> Map.new(&{&1.skill, &1})

    assert by_skill[:confidence].level == :high
    assert by_skill[:persistence].level == :moderate
    assert by_skill[:organization].level == :low
    assert by_skill[:getting_along].level == :low
    assert by_skill[:resilience].level == :low
    assert by_skill[:curiosity].level == :low
  end

  test "zero responses is a no-op (no scores created)", %{admin: admin, school: school} do
    student = create_student!(school, %{first_name: "Ze", last_name: "Ro"})

    {:ok, a} =
      Assessments.assign_resiliency(student.id, :grades_9_12,
        actor: admin,
        tenant: school.id
      )

    assert :ok = run(a, school)
    assert [] == scores_for(student, school)
  end

  test "re-running is idempotent — same 6 rows, no dups", %{admin: admin, school: school} do
    student = create_student!(school, %{first_name: "Id", last_name: "Empotent"})
    a = assign_18_responses(admin, school, student, 3)

    assert :ok = run(a, school)
    first = scores_for(student, school)
    assert length(first) == 6

    assert :ok = run(a, school)
    second = scores_for(student, school)
    assert length(second) == 6
    assert Enum.map(first, & &1.id) |> Enum.sort() == Enum.map(second, & &1.id) |> Enum.sort()
  end
end
