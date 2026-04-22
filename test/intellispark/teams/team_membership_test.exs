defmodule Intellispark.Teams.TeamMembershipTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.TeamsFixtures

  require Ash.Query

  alias Intellispark.Teams
  alias Intellispark.Teams.TeamMembership

  setup do: setup_world()

  describe ":create" do
    test "stamps added_by_id from actor", %{school: school, admin: admin} do
      student = create_student!(school)
      staff = register_staff!(school, :counselor)

      tm = create_team_membership!(admin, school, student, staff, :coach)

      assert tm.added_by_id == admin.id
      assert tm.role == :coach
      assert tm.source == :manual
    end

    test "duplicate (student, user, role) raises identity error", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school)
      staff = register_staff!(school, :counselor)

      _ = create_team_membership!(admin, school, student, staff, :teacher)

      assert {:error, _} =
               Teams.create_team_membership(student.id, staff.id, :teacher,
                 actor: admin,
                 tenant: school.id,
                 authorize?: false
               )
    end
  end

  describe ":update / :destroy" do
    test "update changes role + creates Version row", %{school: school, admin: admin} do
      student = create_student!(school)
      staff = register_staff!(school, :counselor)
      tm = create_team_membership!(admin, school, student, staff, :coach)

      {:ok, updated} =
        Teams.update_team_membership(tm, %{role: :counselor},
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      assert updated.role == :counselor

      versions =
        TeamMembership.Version
        |> Ash.Query.filter(version_source_id == ^tm.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(versions) >= 2
    end

    test "destroy removes the row + lands a destroy version", %{school: school, admin: admin} do
      student = create_student!(school)
      staff = register_staff!(school, :counselor)
      tm = create_team_membership!(admin, school, student, staff, :coach)

      :ok =
        Teams.destroy_team_membership(tm,
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      versions =
        TeamMembership.Version
        |> Ash.Query.filter(version_source_id == ^tm.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert Enum.any?(versions, &(&1.version_action_name == :destroy))
    end
  end

  describe ":add_members_from_roster" do
    test "is idempotent — running twice yields the same row count", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school)
      staff = for _ <- 1..3, do: register_staff!(school, :teacher)
      ids = Enum.map(staff, & &1.id)

      _ =
        Teams.add_members_from_roster(student.id, ids, :teacher,
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      _ =
        Teams.add_members_from_roster(student.id, ids, :teacher,
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      rows =
        TeamMembership
        |> Ash.Query.filter(student_id == ^student.id and role == :teacher)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(rows) == 3
    end
  end
end
