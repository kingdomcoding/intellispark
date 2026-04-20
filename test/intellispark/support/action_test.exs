defmodule Intellispark.Support.ActionTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.SupportFixtures

  require Ash.Query

  alias Intellispark.Support
  alias Intellispark.Support.Action

  setup do: setup_world()

  describe ":create" do
    test "lands in :pending + stamps opened_by_id from actor", %{school: school, admin: admin} do
      student = create_student!(school)
      action = create_action!(admin, school, student, admin, %{description: "check in"})

      assert action.status == :pending
      assert action.opened_by_id == admin.id
      assert action.assignee_id == admin.id
      assert action.description == "check in"
    end

    test "round-trips a due_on date", %{school: school, admin: admin} do
      student = create_student!(school)
      due = Date.add(Date.utc_today(), 5)
      action = create_action!(admin, school, student, admin, %{due_on: due})

      assert action.due_on == due
    end
  end

  describe ":complete" do
    test "transitions :pending → :completed + stamps completed_at", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school)
      action = create_action!(admin, school, student, admin)

      done = complete_action!(action, admin)

      assert done.status == :completed
      assert done.completed_at != nil
      assert done.completed_by_id == admin.id
    end

    test ":complete from :cancelled raises NoMatchingTransition", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school)
      action = create_action!(admin, school, student, admin)
      cancelled = cancel_action!(action, admin, "oops")

      assert {:error, _} =
               Support.complete_action(cancelled,
                 actor: admin,
                 tenant: school.id,
                 authorize?: false
               )
    end
  end

  describe ":cancel" do
    test "transitions :pending → :cancelled + stores reason", %{school: school, admin: admin} do
      student = create_student!(school)
      action = create_action!(admin, school, student, admin)

      cancelled = cancel_action!(action, admin, "raised in error")

      assert cancelled.status == :cancelled
      assert cancelled.cancellation_reason == "raised in error"
    end

    test ":cancel from :completed raises NoMatchingTransition", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school)
      action = create_action!(admin, school, student, admin)
      done = complete_action!(action, admin)

      assert {:error, _} =
               Support.cancel_action(done, %{reason: "nope"},
                 actor: admin,
                 tenant: school.id,
                 authorize?: false
               )
    end
  end

  describe "paper trail" do
    test "writes an Action.Version row per transition", %{school: school, admin: admin} do
      student = create_student!(school)
      action = create_action!(admin, school, student, admin)
      _ = complete_action!(action, admin)

      versions =
        Action.Version
        |> Ash.Query.filter(version_source_id == ^action.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      action_names = Enum.map(versions, & &1.version_action_name) |> Enum.sort()
      assert :create in action_names
      assert :complete in action_names
    end
  end
end
