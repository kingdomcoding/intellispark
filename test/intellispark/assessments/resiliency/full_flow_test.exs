defmodule Intellispark.Assessments.Resiliency.FullFlowTest do
  use Intellispark.DataCase

  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Assessments
  alias Intellispark.Assessments.Resiliency.{QuestionBank, SkillScore}

  setup do
    ctx = setup_world()
    _ = set_school_tier!(ctx.school, :pro)
    school = Ash.load!(ctx.school, [:subscription], authorize?: false)
    admin = Map.put(ctx.admin, :current_school, school)
    ctx |> Map.put(:school, school) |> Map.put(:admin, admin)
  end

  test "full flow: assign -> 18 responses -> submit -> drain Oban -> 6 scores persisted", %{
    admin: admin,
    school: school
  } do
    student = create_student!(school, %{first_name: "Fu", last_name: "Ll"})

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
          3,
          tenant: school.id,
          authorize?: false
        )
    end

    {:ok, _started} = Assessments.start_resiliency(a, actor: admin, tenant: school.id)
    {:ok, _submitted} = Assessments.submit_resiliency(a, actor: admin, tenant: school.id)

    assert %{success: 1} = Oban.drain_queue(queue: :indicators)

    scores =
      SkillScore
      |> Ash.Query.filter(student_id == ^student.id)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)

    assert length(scores) == 6
    assert Enum.all?(scores, &(&1.level == :moderate))
    assert Enum.all?(scores, &(&1.score_value == 3.0))
  end
end
