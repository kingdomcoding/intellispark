defmodule Intellispark.Support.PoliciesTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.SupportFixtures

  alias Intellispark.Accounts.{User, UserSchoolMembership}
  alias Intellispark.Support
  alias Intellispark.Support.Note

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

  describe "Action policies" do
    test "non-assignee teacher cannot complete another's Action", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school)
      action = create_action!(admin, school, student, admin)
      other_teacher = user_with_role!(school, :teacher)

      assert {:error, _} =
               Support.complete_action(action, actor: other_teacher, tenant: school.id)
    end

    test "assignee can complete their own Action", %{school: school, admin: admin} do
      student = create_student!(school)
      teacher = user_with_role!(school, :teacher)
      action = create_action!(admin, school, student, teacher)

      {:ok, done} = Support.complete_action(action, actor: teacher, tenant: school.id)
      assert done.status == :completed
    end

    test "admin CAN complete anyone's Action", %{school: school, admin: admin} do
      student = create_student!(school)
      teacher = user_with_role!(school, :teacher)
      action = create_action!(admin, school, student, teacher)

      {:ok, done} = Support.complete_action(action, actor: admin, tenant: school.id)
      assert done.status == :completed
    end
  end

  describe "Support policies" do
    test "counselor can advance Support states", %{school: school, admin: admin} do
      student = create_student!(school)
      support = create_support!(admin, school, student)
      counselor = user_with_role!(school, :counselor)

      {:ok, accepted} = Support.accept_support(support, actor: counselor, tenant: school.id)
      assert accepted.status == :in_progress
    end

    test "unrelated teacher cannot advance Support states", %{school: school, admin: admin} do
      student = create_student!(school)
      support = create_support!(admin, school, student)
      teacher = user_with_role!(school, :teacher)

      assert {:error, _} =
               Support.accept_support(support, actor: teacher, tenant: school.id)
    end

    test "provider staff can advance their Support", %{school: school, admin: admin} do
      student = create_student!(school)
      provider = user_with_role!(school, :teacher)

      support =
        create_support!(admin, school, student, %{provider_staff_id: provider.id})

      {:ok, accepted} = Support.accept_support(support, actor: provider, tenant: school.id)
      assert accepted.status == :in_progress
    end
  end

  describe "Note policies" do
    test "author can update their own note", %{school: school, admin: _admin} do
      student = create_student!(school)
      teacher = user_with_role!(school, :teacher)
      note = create_note!(teacher, school, student, %{body: "mine"})

      {:ok, updated} =
        Support.update_note(note, %{body: "edited"}, actor: teacher, tenant: school.id)

      assert updated.body == "edited"
    end

    test "non-author teacher cannot update another's note", %{school: school, admin: admin} do
      student = create_student!(school)
      note = create_note!(admin, school, student)
      other_teacher = user_with_role!(school, :teacher)

      assert {:error, _} =
               Support.update_note(note, %{body: "hijack"},
                 actor: other_teacher,
                 tenant: school.id
               )
    end

    test "teacher cannot read a sensitive note", %{school: school, admin: admin} do
      student = create_student!(school)
      note = create_note!(admin, school, student, %{sensitive?: true})
      teacher = user_with_role!(school, :teacher)

      {:ok, rows} = Note |> Ash.Query.set_tenant(school.id) |> Ash.read(actor: teacher)
      refute Enum.any?(rows, &(&1.id == note.id))
    end

    test "counselor CAN read sensitive notes", %{school: school, admin: admin} do
      student = create_student!(school)
      note = create_note!(admin, school, student, %{sensitive?: true})
      counselor = user_with_role!(school, :counselor)

      {:ok, rows} = Note |> Ash.Query.set_tenant(school.id) |> Ash.read(actor: counselor)
      assert Enum.any?(rows, &(&1.id == note.id))
    end
  end
end
