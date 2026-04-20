defmodule Intellispark.Students.CustomListTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Students
  alias Intellispark.Students.{CustomList, FilterSpec}

  setup do: setup_world()

  describe "CustomList basics" do
    test "create stamps owner_id from actor", %{school: school, admin: admin} do
      {:ok, list} =
        Ash.create(
          CustomList,
          %{name: "My List", filters: %{}},
          tenant: school.id,
          actor: admin,
          authorize?: true
        )

      assert list.owner_id == admin.id
      assert list.shared? == false
    end

    test "filters round-trip as FilterSpec struct", %{school: school, admin: admin} do
      {:ok, list} =
        Ash.create(
          CustomList,
          %{
            name: "Grade 9 IEPs",
            filters: %{grade_levels: [9], name_contains: "Ava"}
          },
          tenant: school.id,
          actor: admin,
          authorize?: false
        )

      assert %FilterSpec{} = list.filters
      assert list.filters.grade_levels == [9]
      assert list.filters.name_contains == "Ava"
    end
  end

  describe "run action" do
    test "returns students matching the saved tag filter", %{school: school, admin: admin} do
      tag_a = create_tag!(school, %{name: "Has-IEP"})
      tag_b = create_tag!(school, %{name: "Other"})

      included = create_student!(school, %{first_name: "In", last_name: "Cluded"})
      excluded = create_student!(school, %{first_name: "Ex", last_name: "Cluded"})

      apply_tag!(admin, school, included, tag_a)
      apply_tag!(admin, school, excluded, tag_b)

      {:ok, list} =
        Ash.create(
          CustomList,
          %{name: "IEPs", filters: %{tag_ids: [tag_a.id]}},
          tenant: school.id,
          actor: admin,
          authorize?: false
        )

      {:ok, rows} = Students.run_custom_list(list.id, tenant: school.id, actor: admin)

      ids = MapSet.new(Enum.map(rows, & &1.id))
      assert MapSet.member?(ids, included.id)
      refute MapSet.member?(ids, excluded.id)
    end

    test "name_contains matches preferred_name + first/last (case insensitive)", %{
      school: school,
      admin: admin
    } do
      hit = create_student!(school, %{first_name: "Marcus", last_name: "X", preferred_name: "MJ"})
      _miss = create_student!(school, %{first_name: "Nope", last_name: "Nada"})

      {:ok, list} =
        Ash.create(
          CustomList,
          %{name: "mj lookup", filters: %{name_contains: "mj"}},
          tenant: school.id,
          actor: admin,
          authorize?: false
        )

      {:ok, rows} = Students.run_custom_list(list.id, tenant: school.id, actor: admin)
      ids = Enum.map(rows, & &1.id)
      assert hit.id in ids
      assert length(rows) == 1
    end

    test "grade_levels filter narrows results", %{school: school, admin: admin} do
      grade_9 = create_student!(school, %{first_name: "G", last_name: "9", grade_level: 9})

      _grade_10 =
        create_student!(school, %{first_name: "G", last_name: "10", grade_level: 10})

      {:ok, list} =
        Ash.create(
          CustomList,
          %{name: "Ninth", filters: %{grade_levels: [9]}},
          tenant: school.id,
          actor: admin,
          authorize?: false
        )

      {:ok, rows} = Students.run_custom_list(list.id, tenant: school.id, actor: admin)
      assert Enum.map(rows, & &1.id) == [grade_9.id]
    end
  end
end
