defmodule Intellispark.Teams.StrengthTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.TeamsFixtures

  require Ash.Query

  alias Intellispark.Teams
  alias Intellispark.Teams.Strength

  setup do: setup_world()

  describe "display_order auto-increment" do
    test "first strength gets display_order 1", %{school: school, admin: admin} do
      student = create_student!(school)
      s = create_strength!(admin, school, student, "Creativity")
      assert s.display_order == 1
    end

    test "three sequential creates → 1, 2, 3", %{school: school, admin: admin} do
      student = create_student!(school)
      a = create_strength!(admin, school, student, "Creativity")
      b = create_strength!(admin, school, student, "Soccer")
      c = create_strength!(admin, school, student, "Writing")

      assert a.display_order == 1
      assert b.display_order == 2
      assert c.display_order == 3
    end

    test "stamps added_by_id from actor", %{school: school, admin: admin} do
      student = create_student!(school)
      s = create_strength!(admin, school, student, "Curiosity")
      assert s.added_by_id == admin.id
    end
  end

  describe ":update / :destroy" do
    test "update changes description + lands a Version row", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school)
      s = create_strength!(admin, school, student, "Creativity")

      {:ok, updated} =
        Teams.update_strength(s, %{description: "Artistic creativity"},
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      assert updated.description == "Artistic creativity"

      versions =
        Strength.Version
        |> Ash.Query.filter(version_source_id == ^s.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(versions) >= 2
    end
  end
end
