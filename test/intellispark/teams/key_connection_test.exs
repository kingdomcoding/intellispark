defmodule Intellispark.Teams.KeyConnectionTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.TeamsFixtures

  require Ash.Query

  alias Intellispark.Teams
  alias Intellispark.Teams.KeyConnection

  setup do: setup_world()

  describe ":create" do
    test "creates with note + default :added_manually source", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school)
      staff = register_staff!(school, :counselor)

      kc =
        create_key_connection!(admin, school, student, staff, %{
          note: "added by admin"
        })

      assert kc.note == "added by admin"
      assert kc.source == :added_manually
      assert kc.added_by_id == admin.id

      versions =
        KeyConnection.Version
        |> Ash.Query.filter(version_source_id == ^kc.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      assert length(versions) >= 1
    end

    test "supports :self_reported source", %{school: school, admin: admin} do
      student = create_student!(school)
      staff = register_staff!(school, :counselor)

      kc =
        create_key_connection!(admin, school, student, staff, %{
          source: :self_reported,
          note: "self-reported on Insightfull"
        })

      assert kc.source == :self_reported
    end

    test "duplicate (student, connected_user) raises identity error", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school)
      staff = register_staff!(school, :counselor)

      _ = create_key_connection!(admin, school, student, staff, %{})

      assert {:error, _} =
               Teams.create_key_connection(student.id, staff.id, %{},
                 actor: admin,
                 tenant: school.id,
                 authorize?: false
               )
    end
  end

  describe "tenant isolation" do
    test "school A connections invisible from school B", %{
      school: school_a,
      admin: admin,
      district: district
    } do
      school_b = add_second_school!(district, "Other High", "oh")

      student_a = create_student!(school_a)
      staff_a = register_staff!(school_a, :counselor)
      _ = create_key_connection!(admin, school_a, student_a, staff_a, %{})

      rows_b =
        KeyConnection
        |> Ash.Query.set_tenant(school_b.id)
        |> Ash.read!(authorize?: false)

      assert rows_b == []
    end
  end
end
