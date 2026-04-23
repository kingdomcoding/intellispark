defmodule Intellispark.Students.Calculations.ContributingFactorsTest do
  use Intellispark.DataCase

  import Intellispark.StudentsFixtures

  alias Intellispark.Assessments

  setup do
    ctx = setup_world()
    _ = set_school_tier!(ctx.school, :pro)
    school = Ash.load!(ctx.school, [:subscription], authorize?: false)
    Map.put(ctx, :school, school)
  end

  defp seed!(school, student, skill, value, level) do
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

  defp factors_for(student, school) do
    loaded = Ash.load!(student, [:contributing_factors], tenant: school.id, authorize?: false)
    loaded.contributing_factors
  end

  test "returns the single lowest non-high skill when there is only one", %{school: school} do
    student = create_student!(school, %{first_name: "Si", last_name: "Ngle"})
    seed!(school, student, :confidence, 3.8, :high)
    seed!(school, student, :persistence, 3.8, :high)
    seed!(school, student, :organization, 3.8, :high)
    seed!(school, student, :getting_along, 3.8, :high)
    seed!(school, student, :resilience, 3.8, :high)
    seed!(school, student, :curiosity, 1.0, :low)

    assert factors_for(student, school) == [:curiosity]
  end

  test "returns the 2 lowest when multiple non-high skills exist", %{school: school} do
    student = create_student!(school, %{first_name: "Tw", last_name: "O"})
    seed!(school, student, :confidence, 4.5, :high)
    seed!(school, student, :persistence, 4.5, :high)
    seed!(school, student, :organization, 4.5, :high)
    seed!(school, student, :getting_along, 2.0, :low)
    seed!(school, student, :resilience, 2.9, :moderate)
    seed!(school, student, :curiosity, 1.0, :low)

    assert factors_for(student, school) == [:curiosity, :getting_along]
  end

  test "returns [] when all skills are :high and index is :low", %{school: school} do
    student = create_student!(school, %{first_name: "Al", last_name: "LHigh"})

    for skill <- [
          :confidence,
          :persistence,
          :organization,
          :getting_along,
          :resilience,
          :curiosity
        ] do
      seed!(school, student, skill, 4.5, :high)
    end

    assert factors_for(student, school) == []
  end
end
