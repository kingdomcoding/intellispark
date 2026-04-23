defmodule Intellispark.Students.StudentLifecycleTest do
  use Intellispark.DataCase

  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Accounts.UserSchoolMembership
  alias Intellispark.Students
  alias Intellispark.Students.Student

  setup do
    setup_world()
  end

  defp two_pro_schools_with_district_admin(%{district: district, school: source, admin: admin}) do
    _ = set_school_tier!(source, :pro)

    dest =
      add_second_school!(district, "Sandbox Middle", "sm-#{System.unique_integer([:positive])}")

    _ = set_school_tier!(dest, :pro)

    {:ok, _} =
      Ash.create(
        UserSchoolMembership,
        %{user_id: admin.id, school_id: dest.id, role: :admin, source: :manual},
        authorize?: false
      )

    source = Ash.load!(source, [:subscription], authorize?: false)
    dest = Ash.load!(dest, [:subscription], authorize?: false)

    admin =
      admin
      |> Ash.load!([school_memberships: [:school]], authorize?: false)
      |> Map.put(:current_school, source)

    %{source: source, dest: dest, admin: admin}
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

  describe ":mark_withdrawn" do
    test "sets enrollment_status to :withdrawn", %{admin: admin, school: school} do
      student =
        create_student!(school, %{
          first_name: "With",
          last_name: "Drawn",
          enrollment_status: :active
        })

      {:ok, updated} =
        Students.mark_student_withdrawn(student, actor: admin, tenant: school.id)

      assert updated.enrollment_status == :withdrawn

      admin_reloaded = Ash.load!(admin, [:school_memberships], authorize?: false)

      visible_ids =
        Students.list_students!(actor: admin_reloaded, tenant: school.id)
        |> Enum.map(& &1.id)

      assert student.id in visible_ids
    end

    test "teachers cannot mark withdrawn", %{school: school} do
      student = create_student!(school, %{first_name: "Teach", last_name: "NoWithdraw"})
      teacher = register_teacher!(school)

      assert {:error, %Ash.Error.Forbidden{}} =
               Students.mark_student_withdrawn(student, actor: teacher, tenant: school.id)
    end
  end

  describe ":transfer" do
    setup ctx do
      two_pro_schools_with_district_admin(ctx)
    end

    test "creates a new student in destination school", %{
      source: source,
      dest: dest,
      admin: admin
    } do
      student =
        create_student!(source, %{first_name: "Trans", last_name: "Fer", external_id: "SRC-1"})

      {:ok, _} =
        Students.transfer_student(student, dest.id, actor: admin, tenant: source.id)

      [%Student{} = created] =
        Students.list_students!(actor: admin, tenant: dest.id)
        |> Enum.filter(&(&1.external_id == "SRC-1"))

      assert created.first_name == "Trans"
      assert created.last_name == "Fer"
      assert created.enrollment_status == :active
    end

    test "archives the source student", %{source: source, dest: dest, admin: admin} do
      student =
        create_student!(source, %{first_name: "Arc", last_name: "Source", external_id: "SRC-2"})

      {:ok, archived} =
        Students.transfer_student(student, dest.id, actor: admin, tenant: source.id)

      assert %DateTime{} = archived.archived_at
    end

    test "requires PRO tier on source", %{district: district, admin: admin} do
      starter_source =
        add_second_school!(
          district,
          "Starter Source",
          "starter-#{System.unique_integer([:positive])}"
        )

      _ = set_school_tier!(starter_source, :starter)

      dest =
        add_second_school!(
          district,
          "PRO Dest",
          "prodest-#{System.unique_integer([:positive])}"
        )

      _ = set_school_tier!(dest, :pro)

      {:ok, _} =
        Ash.create(
          UserSchoolMembership,
          %{
            user_id: admin.id,
            school_id: starter_source.id,
            role: :admin,
            source: :manual
          },
          authorize?: false
        )

      {:ok, _} =
        Ash.create(
          UserSchoolMembership,
          %{user_id: admin.id, school_id: dest.id, role: :admin, source: :manual},
          authorize?: false
        )

      starter_source = Ash.load!(starter_source, [:subscription], authorize?: false)

      admin =
        admin
        |> Ash.load!([school_memberships: [:school]], authorize?: false)
        |> Map.put(:current_school, starter_source)

      student =
        create_student!(starter_source, %{
          first_name: "No",
          last_name: "Tier",
          external_id: "STARTER-1"
        })

      assert {:error, %Ash.Error.Forbidden{}} =
               Students.transfer_student(student, dest.id,
                 actor: admin,
                 tenant: starter_source.id
               )

      reloaded = Ash.get!(Student, student.id, tenant: starter_source.id, authorize?: false)
      assert is_nil(reloaded.archived_at)
    end

    test "non-district-admin cannot transfer", %{source: source, dest: dest} do
      teacher = register_teacher!(source)

      student =
        create_student!(source, %{first_name: "No", last_name: "Perm", external_id: "T-1"})

      assert {:error, %Ash.Error.Forbidden{}} =
               Students.transfer_student(student, dest.id, actor: teacher, tenant: source.id)
    end

    test "atomic: create fails on duplicate external_id, source stays active", %{
      source: source,
      dest: dest,
      admin: admin
    } do
      _existing_at_dest =
        create_student!(dest, %{first_name: "Dup", last_name: "Dest", external_id: "DUP-1"})

      student =
        create_student!(source, %{first_name: "Dup", last_name: "Source", external_id: "DUP-1"})

      assert {:error, _} =
               Students.transfer_student(student, dest.id, actor: admin, tenant: source.id)

      reloaded = Ash.get!(Student, student.id, tenant: source.id, authorize?: false)
      assert is_nil(reloaded.archived_at)
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
