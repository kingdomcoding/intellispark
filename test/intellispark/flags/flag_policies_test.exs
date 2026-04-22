defmodule Intellispark.Flags.FlagPoliciesTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.FlagsFixtures

  require Ash.Query

  alias Intellispark.Accounts.{User, UserSchoolMembership}
  alias Intellispark.Flags
  alias Intellispark.Flags.Flag

  setup do: setup_world()

  defp user_with_role!(school, role) do
    user =
      Ash.create!(
        User,
        %{
          email: "#{role}-#{System.unique_integer([:positive])}@sandbox.edu",
          password: "supersecret123",
          password_confirmation: "supersecret123"
        },
        action: :register_with_password,
        authorize?: false
      )

    {:ok, _} =
      Ash.create(
        UserSchoolMembership,
        %{user_id: user.id, school_id: school.id, role: role, source: :manual},
        authorize?: false
      )

    Ash.load!(user, [school_memberships: [:school]], authorize?: false)
  end

  describe "read scoping" do
    test "teacher reads non-sensitive flags in their school", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "R1", last_name: "A"})
      type = create_flag_type!(school, %{name: "Academic-R1"})
      flag = create_flag!(admin, school, student, type)
      open_flag!(flag, [admin.id], admin)

      teacher = user_with_role!(school, :teacher)

      {:ok, rows} = Flag |> Ash.Query.set_tenant(school.id) |> Ash.read(actor: teacher)
      assert Enum.any?(rows, &(&1.id == flag.id))
    end

    test "teacher cannot read sensitive flags in their school", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "R2", last_name: "B"})
      type = create_flag_type!(school, %{name: "MH-R2", default_sensitive?: true})
      flag = create_flag!(admin, school, student, type)
      open_flag!(flag, [admin.id], admin)

      teacher = user_with_role!(school, :teacher)

      {:ok, rows} = Flag |> Ash.Query.set_tenant(school.id) |> Ash.read(actor: teacher)
      refute Enum.any?(rows, &(&1.id == flag.id))
    end

    test "counselor CAN read sensitive flags", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "R3", last_name: "C"})
      type = create_flag_type!(school, %{name: "MH-R3", default_sensitive?: true})
      flag = create_flag!(admin, school, student, type)
      open_flag!(flag, [admin.id], admin)

      counselor = user_with_role!(school, :counselor)

      {:ok, rows} = Flag |> Ash.Query.set_tenant(school.id) |> Ash.read(actor: counselor)
      assert Enum.any?(rows, &(&1.id == flag.id))
    end

    test "actor without any membership sees no flags", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "R4", last_name: "D"})
      type = create_flag_type!(school, %{name: "Academic-R4"})
      create_flag!(admin, school, student, type)

      stranger =
        Ash.create!(
          User,
          %{
            email: "stranger-#{System.unique_integer([:positive])}@sandbox.edu",
            password: "supersecret123",
            password_confirmation: "supersecret123"
          },
          action: :register_with_password,
          authorize?: false
        )
        |> Ash.load!([:school_memberships], authorize?: false)

      {:ok, rows} = Flag |> Ash.Query.set_tenant(school.id) |> Ash.read(actor: stranger)
      assert rows == []
    end
  end

  describe "close_with_resolution" do
    test "assignee can close", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "C1", last_name: "A"})
      type = create_flag_type!(school, %{name: "Academic-C1"})
      flag = create_flag!(admin, school, student, type)
      teacher = user_with_role!(school, :teacher)
      opened = open_flag!(flag, [teacher.id], admin)

      {:ok, closed} =
        Flags.close_flag(opened, %{resolution_note: "done"},
          actor: teacher,
          tenant: school.id
        )

      assert closed.status == :closed
    end

    test "non-assignee teacher cannot close", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "C2", last_name: "B"})
      type = create_flag_type!(school, %{name: "Academic-C2"})
      flag = create_flag!(admin, school, student, type)
      opened = open_flag!(flag, [admin.id], admin)

      other_teacher = user_with_role!(school, :teacher)

      assert {:error, _} =
               Flags.close_flag(opened, %{resolution_note: "nope"},
                 actor: other_teacher,
                 tenant: school.id
               )
    end

    test "counselor (non-assignee) CAN close", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "C3", last_name: "X"})
      type = create_flag_type!(school, %{name: "Academic-C3"})
      flag = create_flag!(admin, school, student, type)
      opened = open_flag!(flag, [admin.id], admin)

      counselor = user_with_role!(school, :counselor)

      {:ok, closed} =
        Flags.close_flag(opened, %{resolution_note: "admin override"},
          actor: counselor,
          tenant: school.id
        )

      assert closed.status == :closed
    end
  end

  describe "reopen" do
    test "opener can reopen", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "Ro1", last_name: "O"})
      type = create_flag_type!(school, %{name: "Academic-Ro1"})
      flag = create_flag!(admin, school, student, type)
      opened = open_flag!(flag, [admin.id], admin)
      closed = close_flag!(opened, "done", admin)

      {:ok, reopened} = Flags.reopen_flag(closed, actor: admin, tenant: school.id)
      assert reopened.status == :reopened
    end

    test "random teacher cannot reopen", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "Ro2", last_name: "P"})
      type = create_flag_type!(school, %{name: "Academic-Ro2"})
      flag = create_flag!(admin, school, student, type)
      opened = open_flag!(flag, [admin.id], admin)
      closed = close_flag!(opened, "done", admin)

      random_teacher = user_with_role!(school, :teacher)

      assert {:error, _} =
               Flags.reopen_flag(closed, actor: random_teacher, tenant: school.id)
    end
  end
end
