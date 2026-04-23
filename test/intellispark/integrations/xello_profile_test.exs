defmodule Intellispark.Integrations.XelloProfileTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures

  alias Intellispark.Integrations

  setup do
    world = setup_world()
    student = create_student!(world.school)
    {:ok, Map.put(world, :student, student)}
  end

  test "upsert creates a new row when none exists", %{school: school, student: student} do
    {:ok, profile} =
      Integrations.upsert_xello_profile(
        %{
          student_id: student.id,
          personality_style: %{"builder_realistic" => "strong"},
          skills: ["Problem solving"]
        },
        tenant: school.id,
        authorize?: false
      )

    assert profile.student_id == student.id
    assert profile.personality_style == %{"builder_realistic" => "strong"}
    assert profile.skills == ["Problem solving"]
    assert profile.last_synced_at != nil
  end

  test "upsert updates existing row in place", %{school: school, student: student} do
    {:ok, first} =
      Integrations.upsert_xello_profile(
        %{student_id: student.id, education_goals: "2-year college"},
        tenant: school.id,
        authorize?: false
      )

    {:ok, second} =
      Integrations.upsert_xello_profile(
        %{student_id: student.id, education_goals: "4-year college"},
        tenant: school.id,
        authorize?: false
      )

    assert second.id == first.id
    assert second.education_goals == "4-year college"
  end

  test "last_synced_at refreshes on every upsert", %{school: school, student: student} do
    {:ok, first} =
      Integrations.upsert_xello_profile(
        %{student_id: student.id, skills: []},
        tenant: school.id,
        authorize?: false
      )

    Process.sleep(10)

    {:ok, second} =
      Integrations.upsert_xello_profile(
        %{student_id: student.id, skills: ["A"]},
        tenant: school.id,
        authorize?: false
      )

    assert DateTime.compare(second.last_synced_at, first.last_synced_at) == :gt
  end
end
