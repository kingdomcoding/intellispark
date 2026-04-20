defmodule Intellispark.Students.StatusTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Students.{Status, Student, StudentStatus}

  setup do: setup_world()

  describe "Status basics" do
    test "name is unique per school", %{school: school} do
      assert {:ok, _} =
               Ash.create(Status, %{name: "Active", color: "#0f0", position: 0},
                 tenant: school.id,
                 authorize?: false
               )

      assert {:error, _} =
               Ash.create(Status, %{name: "Active", color: "#f00", position: 1},
                 tenant: school.id,
                 authorize?: false
               )
    end
  end

  describe "set_status action" do
    test "opens a StudentStatus row and stamps current_status_id", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Q", last_name: "W"})
      status = create_status!(school, %{name: "Watch"})

      {:ok, s2} =
        Ash.update(student, %{status_id: status.id},
          action: :set_status,
          tenant: school.id,
          actor: admin,
          authorize?: false
        )

      assert s2.current_status_id == status.id

      {:ok, rows} =
        StudentStatus
        |> Ash.Query.filter(student_id == ^student.id and is_nil(cleared_at))
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read(authorize?: false)

      assert length(rows) == 1
      assert hd(rows).status_id == status.id
      assert hd(rows).set_by_id == admin.id
    end

    test "re-setting clears the prior row and opens a new one", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "E", last_name: "R"})
      s1 = create_status!(school, %{name: "Watch"})
      s2 = create_status!(school, %{name: "Active"})

      {:ok, _} =
        Ash.update(student, %{status_id: s1.id},
          action: :set_status,
          tenant: school.id,
          actor: admin,
          authorize?: false
        )

      {:ok, student_final} =
        Student
        |> Ash.Query.filter(id == ^student.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read_one(authorize?: false)

      {:ok, _} =
        Ash.update(student_final, %{status_id: s2.id},
          action: :set_status,
          tenant: school.id,
          actor: admin,
          authorize?: false
        )

      {:ok, all_rows} =
        StudentStatus
        |> Ash.Query.filter(student_id == ^student.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read(authorize?: false)

      active = Enum.filter(all_rows, &is_nil(&1.cleared_at))
      cleared = Enum.filter(all_rows, &(not is_nil(&1.cleared_at)))

      assert length(active) == 1
      assert hd(active).status_id == s2.id
      assert length(cleared) == 1
      assert hd(cleared).status_id == s1.id
    end
  end
end
