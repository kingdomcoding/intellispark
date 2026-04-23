defmodule Intellispark.Students.StudentLifecycleTest do
  use Intellispark.DataCase

  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Students
  alias Intellispark.Students.Student

  setup do
    setup_world()
  end

  describe ":archive" do
    test "sets archived_at on the student", %{admin: admin, school: school} do
      student = create_student!(school, %{first_name: "Arch", last_name: "One"})

      {:ok, archived} =
        Students.archive_student(student, actor: admin, tenant: school.id)

      assert %DateTime{} = archived.archived_at
    end

    test "archived students are hidden from default reads", %{admin: admin, school: school} do
      student = create_student!(school, %{first_name: "Hid", last_name: "Den"})

      {:ok, _} = Students.archive_student(student, actor: admin, tenant: school.id)

      admin_reloaded = Ash.load!(admin, [:school_memberships], authorize?: false)

      visible =
        Students.list_students!(actor: admin_reloaded, tenant: school.id)
        |> Enum.map(& &1.id)

      refute student.id in visible
    end

    test "teachers cannot archive", %{school: school} do
      student = create_student!(school, %{first_name: "Tea", last_name: "Cher"})
      teacher = register_teacher!(school)

      assert {:error, %Ash.Error.Forbidden{}} =
               Students.archive_student(student, actor: teacher, tenant: school.id)
    end

    test "AshPaperTrail captures the :archive event", %{admin: admin, school: school} do
      student = create_student!(school, %{first_name: "Pap", last_name: "Trail"})

      {:ok, _} = Students.archive_student(student, actor: admin, tenant: school.id)

      versions =
        Student.Version
        |> Ash.Query.filter(version_source_id == ^student.id)
        |> Ash.read!(authorize?: false, tenant: school.id)

      names = Enum.map(versions, & &1.version_action_name) |> Enum.sort()
      assert :archive in names

      archive_version = Enum.find(versions, &(&1.version_action_name == :archive))
      assert Map.has_key?(archive_version.changes, "archived_at")
    end
  end

  describe ":unarchive" do
    test "clears archived_at; restored student reappears", %{admin: admin, school: school} do
      student = create_student!(school, %{first_name: "Un", last_name: "Archive"})

      {:ok, archived} = Students.archive_student(student, actor: admin, tenant: school.id)
      assert archived.archived_at != nil

      {:ok, restored} = Students.unarchive_student(archived, actor: admin, tenant: school.id)
      assert is_nil(restored.archived_at)

      admin_reloaded = Ash.load!(admin, [:school_memberships], authorize?: false)

      visible =
        Students.list_students!(actor: admin_reloaded, tenant: school.id)
        |> Enum.map(& &1.id)

      assert student.id in visible
    end
  end
end
