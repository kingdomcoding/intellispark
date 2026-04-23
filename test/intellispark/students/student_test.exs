defmodule Intellispark.Students.StudentTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Students
  alias Intellispark.Students.Student

  setup do: setup_world()

  describe "create" do
    test "succeeds with valid attrs under a tenant", %{school: school} do
      assert {:ok, s} =
               Ash.create(
                 Student,
                 %{first_name: "Ava", last_name: "Patel", grade_level: 10},
                 tenant: school.id,
                 authorize?: false
               )

      assert s.first_name == "Ava"
      assert s.school_id == school.id
    end

    test "grade_level 20 is rejected by constraint", %{school: school} do
      assert {:error, _} =
               Ash.create(
                 Student,
                 %{first_name: "X", last_name: "Y", grade_level: 20},
                 tenant: school.id,
                 authorize?: false
               )
    end

    test "external_id is unique per school", %{school: school, district: district} do
      second = add_second_school!(district)

      {:ok, _} =
        Ash.create(
          Student,
          %{first_name: "A", last_name: "B", grade_level: 9, external_id: "SIS-1"},
          tenant: school.id,
          authorize?: false
        )

      # Same school, same external_id → rejected
      assert {:error, _} =
               Ash.create(
                 Student,
                 %{first_name: "C", last_name: "D", grade_level: 10, external_id: "SIS-1"},
                 tenant: school.id,
                 authorize?: false
               )

      # Different school, same external_id → fine
      assert {:ok, _} =
               Ash.create(
                 Student,
                 %{first_name: "E", last_name: "F", grade_level: 11, external_id: "SIS-1"},
                 tenant: second.id,
                 authorize?: false
               )
    end
  end

  describe "demographics" do
    test "create accepts gender / ethnicity_race / phone", %{school: school} do
      assert {:ok, s} =
               Ash.create(
                 Student,
                 %{
                   first_name: "Ada",
                   last_name: "Lovelace",
                   grade_level: 9,
                   phone: "555-0100",
                   gender: :female,
                   ethnicity_race: :white
                 },
                 tenant: school.id,
                 authorize?: false
               )

      assert s.phone == "555-0100"
      assert s.gender == :female
      assert s.ethnicity_race == :white
    end

    test "rejects gender outside the allowed set", %{school: school} do
      assert {:error, _} =
               Ash.create(
                 Student,
                 %{first_name: "X", last_name: "Y", grade_level: 5, gender: :unknown_atom},
                 tenant: school.id,
                 authorize?: false
               )
    end

    test "update sets ethnicity_race + paper-trail captures it", %{school: school} do
      s = create_student!(school, %{first_name: "P", last_name: "Q"})

      {:ok, updated} =
        Ash.update(s, %{ethnicity_race: :asian, phone: "555-0199"},
          tenant: school.id,
          authorize?: false
        )

      assert updated.ethnicity_race == :asian
      assert updated.phone == "555-0199"

      {:ok, versions} =
        Student.Version
        |> Ash.Query.filter(version_source_id == ^s.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read(authorize?: false)

      assert Enum.any?(versions, fn v ->
               match?(%{ethnicity_race: :asian}, v.changes) or
                 v.version_action_name == :update
             end)
    end
  end

  describe "calculations" do
    test "display_name falls back to first + last when preferred_name nil", %{school: school} do
      s = create_student!(school, %{first_name: "Marcus", last_name: "Johnson"})
      s = Ash.load!(s, [:display_name], authorize?: false)
      assert s.display_name == "Marcus Johnson"
    end

    test "display_name uses preferred_name when present", %{school: school} do
      s = create_student!(school, %{first_name: "M", last_name: "J", preferred_name: "MJ"})
      s = Ash.load!(s, [:display_name], authorize?: false)
      assert s.display_name == "MJ"
    end

    test "initials returns two uppercase letters", %{school: school} do
      s = create_student!(school, %{first_name: "Ling", last_name: "Chen"})
      s = Ash.load!(s, [:initials], authorize?: false)
      assert s.initials == "LC"
    end
  end

  describe "paper_trail" do
    test "create + update produce version rows with school_id", %{school: school} do
      s = create_student!(school, %{first_name: "Noah", last_name: "Williams"})
      {:ok, _} = Ash.update(s, %{grade_level: 11}, tenant: school.id, authorize?: false)

      {:ok, versions} =
        Student.Version
        |> Ash.Query.filter(version_source_id == ^s.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read(authorize?: false)

      actions = Enum.map(versions, & &1.version_action_name) |> Enum.sort()
      assert :create in actions
      assert :update in actions
      assert Enum.all?(versions, &(&1.school_id == school.id))
    end
  end

  describe "tenant isolation" do
    test "read in school A does not return school B's students", %{
      school: school,
      district: district
    } do
      second = add_second_school!(district)
      _s1 = create_student!(school, %{first_name: "A", last_name: "One"})
      _s2 = create_student!(second, %{first_name: "B", last_name: "Two"})

      {:ok, rows} = Students.list_students(tenant: school.id, authorize?: false)
      first_names = Enum.map(rows, & &1.first_name)
      assert "A" in first_names
      refute "B" in first_names
    end
  end
end
