defmodule Intellispark.Assessments.Resiliency.AssessmentTest do
  use Intellispark.DataCase

  import Intellispark.StudentsFixtures

  alias Intellispark.Assessments

  setup do
    ctx = setup_world()
    _ = set_school_tier!(ctx.school, :pro)
    school = Ash.load!(ctx.school, [:subscription], authorize?: false)
    admin = Map.put(ctx.admin, :current_school, school)
    ctx |> Map.put(:school, school) |> Map.put(:admin, admin)
  end

  describe ":assign" do
    test "mints a token, stamps version + assigned_at, defaults state :assigned", %{
      admin: admin,
      school: school
    } do
      student = create_student!(school, %{first_name: "A", last_name: "Ss"})

      {:ok, a} =
        Assessments.assign_resiliency(student.id, :grades_9_12,
          actor: admin,
          tenant: school.id
        )

      assert a.state == :assigned
      assert a.version == "v1"
      assert a.grade_band == :grades_9_12
      assert is_binary(a.token)
      assert byte_size(a.token) > 20
      assert %DateTime{} = a.assigned_at
      assert %DateTime{} = a.expires_at
      assert a.assigned_by_id == admin.id
    end

    test "starter-tier clinical admin cannot assign", %{admin: admin, school: school} do
      _ = set_school_tier!(school, :starter)
      starter = Ash.load!(school, [:subscription], authorize?: false)
      starter_admin = Map.put(admin, :current_school, starter)
      student = create_student!(starter, %{first_name: "No", last_name: "Tier"})

      assert {:error, %Ash.Error.Forbidden{}} =
               Assessments.assign_resiliency(student.id, :grades_9_12,
                 actor: starter_admin,
                 tenant: starter.id
               )
    end
  end

  describe "state machine" do
    setup %{admin: admin, school: school} do
      student = create_student!(school, %{first_name: "State", last_name: "Machine"})

      {:ok, a} =
        Assessments.assign_resiliency(student.id, :grades_9_12,
          actor: admin,
          tenant: school.id
        )

      %{assessment: a}
    end

    test "start transitions :assigned -> :in_progress", %{
      assessment: a,
      admin: admin,
      school: school
    } do
      {:ok, updated} = Assessments.start_resiliency(a, actor: admin, tenant: school.id)
      assert updated.state == :in_progress
    end

    test "submit transitions to :submitted and stamps submitted_at", %{
      assessment: a,
      admin: admin,
      school: school
    } do
      {:ok, started} = Assessments.start_resiliency(a, actor: admin, tenant: school.id)
      {:ok, submitted} = Assessments.submit_resiliency(started, actor: admin, tenant: school.id)
      assert submitted.state == :submitted
      assert %DateTime{} = submitted.submitted_at
    end

    test "expire transitions to :expired", %{assessment: a, admin: admin, school: school} do
      {:ok, expired} = Assessments.expire_resiliency(a, actor: admin, tenant: school.id)
      assert expired.state == :expired
    end
  end

  describe ":by_token" do
    test "reads the assessment with multitenancy bypass", %{admin: admin, school: school} do
      student = create_student!(school, %{first_name: "Tok", last_name: "En"})

      {:ok, a} =
        Assessments.assign_resiliency(student.id, :grades_9_12,
          actor: admin,
          tenant: school.id
        )

      {:ok, found} =
        Assessments.get_resiliency_assessment_by_token(a.token, authorize?: false)

      assert found.id == a.id
    end
  end
end
