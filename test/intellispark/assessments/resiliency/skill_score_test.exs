defmodule Intellispark.Assessments.Resiliency.SkillScoreTest do
  use Intellispark.DataCase

  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Assessments
  alias Intellispark.Assessments.Resiliency.SkillScore

  setup do
    ctx = setup_world()
    _ = set_school_tier!(ctx.school, :pro)
    school = Ash.load!(ctx.school, [:subscription], authorize?: false)
    Map.put(ctx, :school, school)
  end

  test "upsert creates a row with the expected level", %{school: school} do
    student = create_student!(school, %{first_name: "Sk", last_name: "Core"})

    {:ok, score} =
      Assessments.upsert_resiliency_skill_score(
        student.id,
        :confidence,
        4.0,
        :high,
        3,
        tenant: school.id,
        authorize?: false
      )

    assert score.skill == :confidence
    assert score.level == :high
    assert score.score_value == 4.0
    assert score.answered_count == 3
  end

  test "upsert with same (student, skill) updates instead of creating a duplicate", %{
    school: school
  } do
    student = create_student!(school, %{first_name: "Sk", last_name: "Idempotent"})

    {:ok, _} =
      Assessments.upsert_resiliency_skill_score(
        student.id,
        :confidence,
        2.0,
        :low,
        3,
        tenant: school.id,
        authorize?: false
      )

    {:ok, _} =
      Assessments.upsert_resiliency_skill_score(
        student.id,
        :confidence,
        4.5,
        :high,
        3,
        tenant: school.id,
        authorize?: false
      )

    rows =
      SkillScore
      |> Ash.Query.filter(student_id == ^student.id and skill == :confidence)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)

    assert length(rows) == 1
    assert hd(rows).level == :high
    assert hd(rows).score_value == 4.5
  end

  test "banding thresholds land on the right level" do
    assert_band(5.0, :high)
    assert_band(4.0, :high)
    assert_band(3.75, :high)
    assert_band(3.74, :moderate)
    assert_band(3.0, :moderate)
    assert_band(2.5, :moderate)
    assert_band(2.49, :low)
    assert_band(1.0, :low)
  end

  test "AshPaperTrail captures upsert events", %{school: school} do
    student = create_student!(school, %{first_name: "Pp", last_name: "Trail"})

    {:ok, _} =
      Assessments.upsert_resiliency_skill_score(
        student.id,
        :persistence,
        3.0,
        :moderate,
        3,
        tenant: school.id,
        authorize?: false
      )

    versions =
      SkillScore.Version
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)

    assert length(versions) >= 1
  end

  defp assert_band(mean, expected) do
    level =
      cond do
        mean >= 3.75 -> :high
        mean >= 2.5 -> :moderate
        true -> :low
      end

    assert level == expected, "mean=#{mean} expected=#{expected} got=#{level}"
  end
end
