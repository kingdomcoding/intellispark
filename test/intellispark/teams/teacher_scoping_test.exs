defmodule Intellispark.Teams.TeacherScopingTest do
  @moduledoc """
  Verifies the Phase 10 Student read policy:

    * admins / counselors / clinical roles see all students in school
    * teachers see ONLY students whose `team_memberships` include them
  """

  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.TeamsFixtures

  require Ash.Query

  alias Intellispark.Students.Student

  setup do: setup_world()

  test "admin sees all students in their school", %{school: school, admin: admin} do
    s1 = create_student!(school, %{first_name: "Alpha"})
    s2 = create_student!(school, %{first_name: "Beta"})

    rows =
      Student
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(actor: admin)

    ids = Enum.map(rows, & &1.id)
    assert s1.id in ids
    assert s2.id in ids
  end

  test "teacher only sees students they're on the team of", %{
    school: school,
    admin: admin
  } do
    teacher = register_staff!(school, :teacher)
    on_team = create_student!(school, %{first_name: "OnTeam"})
    off_team = create_student!(school, %{first_name: "OffTeam"})

    _ = create_team_membership!(admin, school, on_team, teacher, :teacher)

    rows =
      Student
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(actor: teacher)

    ids = Enum.map(rows, & &1.id)
    assert on_team.id in ids
    refute off_team.id in ids
  end

  test "counselor sees all students in school (clinical bypass)", %{
    school: school,
    admin: admin
  } do
    counselor = register_staff!(school, :counselor)
    s1 = create_student!(school, %{first_name: "Gamma"})
    _ = create_student!(school, %{first_name: "Delta"})

    # Counselor has NO team memberships, but should still see all rows.
    rows =
      Student
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(actor: counselor)

    ids = Enum.map(rows, & &1.id)
    assert s1.id in ids
    refute counselor.id == admin.id
  end

  test "removing a teacher from a team revokes read access", %{
    school: school,
    admin: admin
  } do
    teacher = register_staff!(school, :teacher)
    student = create_student!(school, %{first_name: "Once"})

    tm = create_team_membership!(admin, school, student, teacher, :teacher)

    # Teacher can see them now.
    assert [_] =
             Student
             |> Ash.Query.filter(id == ^student.id)
             |> Ash.Query.set_tenant(school.id)
             |> Ash.read!(actor: teacher)

    :ok =
      Intellispark.Teams.destroy_team_membership(tm,
        actor: admin,
        tenant: school.id,
        authorize?: false
      )

    rows =
      Student
      |> Ash.Query.filter(id == ^student.id)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(actor: teacher)

    assert rows == []
  end
end
