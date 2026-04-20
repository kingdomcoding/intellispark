defmodule Intellispark.Students.PolicyTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures

  require Ash.Query

  alias Intellispark.Accounts.{User, UserSchoolMembership}
  alias Intellispark.Students
  alias Intellispark.Students.{CustomList, Student, Tag}

  setup do: setup_world()

  describe "Student reads" do
    test "staff with membership can read students in their school", %{
      school: school,
      admin: admin
    } do
      _s1 = create_student!(school, %{first_name: "A", last_name: "One"})

      {:ok, rows} = Students.list_students(tenant: school.id, actor: admin)
      assert rows != []
    end

    test "staff in school A cannot see students in school B", %{
      school: _school,
      admin: admin,
      district: district
    } do
      other = add_second_school!(district)
      _theirs = create_student!(other, %{first_name: "Other", last_name: "School"})

      {:ok, rows} = Students.list_students(tenant: other.id, actor: admin)
      assert rows == []
    end

    test "actor without any membership sees nothing", %{school: school} do
      _s1 = create_student!(school, %{first_name: "A", last_name: "One"})

      stranger =
        Ash.create!(
          User,
          %{
            email: "stranger@sandbox.edu",
            password: "supersecret123",
            password_confirmation: "supersecret123"
          },
          action: :register_with_password,
          authorize?: false
        )

      stranger = Ash.load!(stranger, [:school_memberships], authorize?: false)

      {:ok, rows} = Students.list_students(tenant: school.id, actor: stranger)
      assert rows == []
    end
  end

  describe "Student edits" do
    test "staff with membership can create a student", %{school: school, admin: admin} do
      assert {:ok, _} =
               Ash.create(
                 Student,
                 %{first_name: "Legit", last_name: "Create", grade_level: 9},
                 tenant: school.id,
                 actor: admin,
                 authorize?: true
               )
    end

    test "actor without membership in the tenant cannot create a student", %{
      school: school,
      district: district
    } do
      other = add_second_school!(district)

      outsider =
        Ash.create!(
          User,
          %{
            email: "outsider@sandbox.edu",
            password: "supersecret123",
            password_confirmation: "supersecret123"
          },
          action: :register_with_password,
          authorize?: false
        )

      {:ok, _} =
        Ash.create(
          UserSchoolMembership,
          %{user_id: outsider.id, school_id: other.id, role: :admin, source: :manual},
          authorize?: false
        )

      outsider = Ash.load!(outsider, [:school_memberships], authorize?: false)

      assert {:error, _} =
               Ash.create(
                 Student,
                 %{first_name: "Bad", last_name: "Create", grade_level: 9},
                 tenant: school.id,
                 actor: outsider,
                 authorize?: true
               )
    end
  end

  describe "CustomList visibility" do
    test "owner sees own private list; non-owner without shared? does not", %{
      school: school,
      admin: admin
    } do
      {:ok, list} =
        Ash.create(
          CustomList,
          %{name: "Private", filters: %{}, shared?: false},
          tenant: school.id,
          actor: admin,
          authorize?: true
        )

      peer =
        Ash.create!(
          User,
          %{
            email: "peer@sandbox.edu",
            password: "supersecret123",
            password_confirmation: "supersecret123"
          },
          action: :register_with_password,
          authorize?: false
        )

      {:ok, _} =
        Ash.create(
          UserSchoolMembership,
          %{user_id: peer.id, school_id: school.id, role: :support_staff, source: :manual},
          authorize?: false
        )

      peer = Ash.load!(peer, [:school_memberships], authorize?: false)

      assert {:ok, _} = Ash.get(CustomList, list.id, tenant: school.id, actor: admin)

      assert {:error, _} =
               Ash.get(CustomList, list.id, tenant: school.id, actor: peer, authorize?: true)
    end

    test "shared? == true makes the list visible to peers in the same school", %{
      school: school,
      admin: admin
    } do
      {:ok, list} =
        Ash.create(
          CustomList,
          %{name: "Shared", filters: %{}, shared?: true},
          tenant: school.id,
          actor: admin,
          authorize?: true
        )

      peer =
        Ash.create!(
          User,
          %{
            email: "peer2@sandbox.edu",
            password: "supersecret123",
            password_confirmation: "supersecret123"
          },
          action: :register_with_password,
          authorize?: false
        )

      {:ok, _} =
        Ash.create(
          UserSchoolMembership,
          %{user_id: peer.id, school_id: school.id, role: :support_staff, source: :manual},
          authorize?: false
        )

      peer = Ash.load!(peer, [:school_memberships], authorize?: false)

      assert {:ok, _} =
               Ash.get(CustomList, list.id, tenant: school.id, actor: peer, authorize?: true)
    end
  end

  describe "Tag edits" do
    test "staff in school can create a tag in that school", %{school: school, admin: admin} do
      assert {:ok, _} =
               Ash.create(
                 Tag,
                 %{name: "Policy-Tag", color: "#123"},
                 tenant: school.id,
                 actor: admin,
                 authorize?: true
               )
    end
  end
end
