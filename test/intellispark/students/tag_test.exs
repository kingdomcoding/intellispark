defmodule Intellispark.Students.TagTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Students
  alias Intellispark.Students.{StudentTag, Tag}

  setup do: setup_world()

  describe "Tag basics" do
    test "name is unique per school", %{school: school} do
      assert {:ok, _} =
               Ash.create(Tag, %{name: "IEP", color: "#000"},
                 tenant: school.id,
                 authorize?: false
               )

      assert {:error, _} =
               Ash.create(Tag, %{name: "IEP", color: "#fff"},
                 tenant: school.id,
                 authorize?: false
               )
    end
  end

  describe "StudentTag join" do
    test "apply_tag sets applied_by = actor", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "A", last_name: "B"})
      tag = create_tag!(school, %{name: "Tag-Apply-By"})

      {:ok, join} =
        Ash.create(
          StudentTag,
          %{student_id: student.id, tag_id: tag.id},
          tenant: school.id,
          actor: admin,
          authorize?: false
        )

      assert join.applied_by_id == admin.id
    end

    test "duplicate (student, tag) is rejected by identity", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "C", last_name: "D"})
      tag = create_tag!(school, %{name: "Tag-Dup"})

      apply_tag!(admin, school, student, tag)

      assert {:error, _} =
               Ash.create(
                 StudentTag,
                 %{student_id: student.id, tag_id: tag.id},
                 tenant: school.id,
                 actor: admin,
                 authorize?: false
               )
    end
  end

  describe "bulk apply_to_students" do
    test "creates StudentTag for every listed student", %{school: school, admin: admin} do
      tag = create_tag!(school, %{name: "Tag-Bulk"})

      students =
        for i <- 1..3 do
          create_student!(school, %{first_name: "S#{i}", last_name: "L#{i}"})
        end

      ids = Enum.map(students, & &1.id)

      {:ok, _tag} =
        Students.apply_tag_to_students(tag.id, ids,
          actor: admin,
          tenant: school.id
        )

      {:ok, rows} =
        StudentTag
        |> Ash.Query.filter(tag_id == ^tag.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read(authorize?: false)

      assert length(rows) == 3
      assert MapSet.new(Enum.map(rows, & &1.student_id)) == MapSet.new(ids)
    end

    test "upsert makes re-apply idempotent", %{school: school, admin: admin} do
      tag = create_tag!(school, %{name: "Tag-Idempotent"})
      student = create_student!(school, %{first_name: "X", last_name: "Y"})

      {:ok, _} =
        Students.apply_tag_to_students(tag.id, [student.id],
          actor: admin,
          tenant: school.id
        )

      {:ok, _} =
        Students.apply_tag_to_students(tag.id, [student.id],
          actor: admin,
          tenant: school.id
        )

      {:ok, rows} =
        StudentTag
        |> Ash.Query.filter(student_id == ^student.id and tag_id == ^tag.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read(authorize?: false)

      assert length(rows) == 1
    end
  end
end
