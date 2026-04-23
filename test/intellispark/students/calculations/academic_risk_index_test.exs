defmodule Intellispark.Students.Calculations.AcademicRiskIndexTest do
  use Intellispark.DataCase

  import Intellispark.StudentsFixtures

  alias Intellispark.Assessments

  @skills ~w(confidence persistence organization getting_along resilience curiosity)a

  setup do
    ctx = setup_world()
    _ = set_school_tier!(ctx.school, :pro)
    school = Ash.load!(ctx.school, [:subscription], authorize?: false)
    Map.put(ctx, :school, school)
  end

  defp seed_all_skills!(school, student, value, level) do
    for skill <- @skills do
      {:ok, _} =
        Assessments.upsert_resiliency_skill_score(
          student.id,
          skill,
          value,
          level,
          3,
          tenant: school.id,
          authorize?: false
        )
    end
  end

  defp index_for(student, school) do
    loaded = Ash.load!(student, [:academic_risk_index], tenant: school.id, authorize?: false)
    loaded.academic_risk_index
  end

  test "all skills at 5.0 -> :low (mean >= 3.75)", %{school: school} do
    student = create_student!(school, %{first_name: "L", last_name: "Ow"})
    seed_all_skills!(school, student, 5.0, :high)
    assert index_for(student, school) == :low
  end

  test "all skills at 3.0 -> :moderate (2.5 <= mean < 3.75)", %{school: school} do
    student = create_student!(school, %{first_name: "M", last_name: "Od"})
    seed_all_skills!(school, student, 3.0, :moderate)
    assert index_for(student, school) == :moderate
  end

  test "all skills at 2.0 -> :high (1.25 <= mean < 2.5)", %{school: school} do
    student = create_student!(school, %{first_name: "H", last_name: "Ig"})
    seed_all_skills!(school, student, 2.0, :low)
    assert index_for(student, school) == :high
  end

  test "all skills at 0.5 -> :critical (mean < 1.25)", %{school: school} do
    student = create_student!(school, %{first_name: "C", last_name: "Rit"})
    seed_all_skills!(school, student, 0.5, :low)
    assert index_for(student, school) == :critical
  end

  test "student with no skill scores -> nil", %{school: school} do
    student = create_student!(school, %{first_name: "Ni", last_name: "L"})
    assert index_for(student, school) == nil
  end
end
