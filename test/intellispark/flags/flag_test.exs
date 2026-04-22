defmodule Intellispark.Flags.FlagTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.FlagsFixtures

  require Ash.Query

  alias Intellispark.Flags
  alias Intellispark.Flags.{Flag, FlagAssignment}

  setup do: setup_world()

  describe ":create action" do
    test "lands in :draft + stamps opened_by from actor", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Draft", last_name: "Case"})
      type = create_flag_type!(school)

      flag = create_flag!(admin, school, student, type)

      assert flag.status == :draft
      assert flag.opened_by_id == admin.id
      assert flag.short_description != nil
    end

    test "inherits sensitive? from flag type default_sensitive?", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Sens", last_name: "Case"})

      sensitive_type =
        create_flag_type!(school, %{name: "MentalHealthFix", default_sensitive?: true})

      flag = create_flag!(admin, school, student, sensitive_type)

      assert flag.sensitive? == true
    end

    test "defaults auto_close_at ~30 days out when not provided", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Auto", last_name: "Close"})
      type = create_flag_type!(school)

      flag = create_flag!(admin, school, student, type)

      now = DateTime.utc_now()
      diff_days = DateTime.diff(flag.auto_close_at, now, :second) / 86_400

      assert diff_days > 29 and diff_days < 31
    end
  end

  describe "state machine" do
    test ":open_flag transitions from :draft to :open + creates assignments", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Open", last_name: "Me"})
      type = create_flag_type!(school)
      flag = create_flag!(admin, school, student, type)

      opened = open_flag!(flag, [admin.id], admin)

      assert opened.status == :open
      assert active_assignments(school, flag.id) |> length() == 1
    end

    test ":close_with_resolution from :draft is rejected by the state machine", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Reject", last_name: "Close"})
      type = create_flag_type!(school)
      flag = create_flag!(admin, school, student, type)

      assert {:error, _} =
               Flags.close_flag(flag, %{resolution_note: "nope"},
                 actor: admin,
                 tenant: school.id,
                 authorize?: false
               )
    end

    test "close_with_resolution accepts empty resolution_note", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Empty", last_name: "Note"})
      type = create_flag_type!(school, %{name: "EmptyNoteType"})
      flag = create_flag!(admin, school, student, type)
      opened = open_flag!(flag, [admin.id], admin)

      {:ok, closed} =
        Flags.close_flag(opened, %{resolution_note: ""},
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      assert closed.status == :closed
      assert closed.resolution_note in [nil, ""]
    end

    test "close_with_resolution sets followup_at when provided", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "With", last_name: "Followup"})
      type = create_flag_type!(school, %{name: "WithFollowupType"})
      flag = create_flag!(admin, school, student, type)
      opened = open_flag!(flag, [admin.id], admin)
      date = Date.utc_today() |> Date.add(7)

      {:ok, closed} =
        Flags.close_flag(opened, %{followup_at: date},
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      assert closed.status == :closed
      assert closed.followup_at == date
    end

    test "close_with_resolution ignores nil followup_at", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Nil", last_name: "Followup"})
      type = create_flag_type!(school, %{name: "NilFollowupType"})
      flag = create_flag!(admin, school, student, type)
      opened = open_flag!(flag, [admin.id], admin)

      {:ok, closed} =
        Flags.close_flag(opened, %{followup_at: nil},
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      assert closed.status == :closed
      assert closed.followup_at == nil
    end

    test "full happy path: draft → open → assigned → closed → reopened", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Full", last_name: "Cycle"})
      type = create_flag_type!(school)

      flag = create_flag!(admin, school, student, type)
      opened = open_flag!(flag, [admin.id], admin)
      assert opened.status == :open

      {:ok, assigned} =
        Flags.assign_flag(opened, [admin.id],
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      assert assigned.status == :assigned

      closed = close_flag!(assigned, "resolved", admin)
      assert closed.status == :closed
      assert closed.resolution_note == "resolved"

      {:ok, reopened} =
        Flags.reopen_flag(closed, actor: admin, tenant: school.id, authorize?: false)

      assert reopened.status == :reopened
      assert is_nil(reopened.resolution_note)
    end

    test ":set_followup records the date + transitions to pending_followup", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Follow", last_name: "Up"})
      type = create_flag_type!(school)
      flag = create_flag!(admin, school, student, type)
      opened = open_flag!(flag, [admin.id], admin)

      target = Date.add(Date.utc_today(), 7)
      updated = set_followup!(opened, target, admin)

      assert updated.status == :pending_followup
      assert updated.followup_at == target
    end

    test ":auto_close sets a canned resolution note", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "Auto", last_name: "Stale"})
      type = create_flag_type!(school)
      flag = create_flag!(admin, school, student, type)
      opened = open_flag!(flag, [admin.id], admin)

      {:ok, closed} =
        Flags.auto_close_flag(opened, tenant: school.id, authorize?: false)

      assert closed.status == :closed
      assert closed.resolution_note =~ "Auto-closed"
    end
  end

  describe "paper-trail versions" do
    test "every transition creates a Flag.Version row", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "Version", last_name: "Trail"})
      type = create_flag_type!(school)

      flag = create_flag!(admin, school, student, type)
      _opened = open_flag!(flag, [admin.id], admin)

      {:ok, versions} =
        Flag.Version
        |> Ash.Query.filter(version_source_id == ^flag.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read(authorize?: false)

      action_names = Enum.map(versions, & &1.version_action_name) |> Enum.sort()
      assert :create in action_names
      assert :open_flag in action_names
    end
  end

  describe "SyncAssignments change" do
    test "assign diff adds new, clears removed", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "Diff", last_name: "Assign"})
      type = create_flag_type!(school)
      flag = create_flag!(admin, school, student, type)
      opened = open_flag!(flag, [admin.id], admin)

      peer =
        Ash.create!(
          Intellispark.Accounts.User,
          %{
            email: "peer-flag-#{System.unique_integer([:positive])}@sandbox.edu",
            password: "supersecret123",
            password_confirmation: "supersecret123"
          },
          action: :register_with_password,
          authorize?: false
        )

      {:ok, _} =
        Ash.create(
          Intellispark.Accounts.UserSchoolMembership,
          %{user_id: peer.id, school_id: school.id, role: :counselor, source: :manual},
          authorize?: false
        )

      # Reassign to peer only — admin should be cleared, peer added.
      {:ok, _} =
        Flags.assign_flag(opened, [peer.id],
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      active = active_assignments(school, flag.id)
      assert length(active) == 1
      assert hd(active).user_id == peer.id

      all_assignments =
        FlagAssignment
        |> Ash.Query.filter(flag_id == ^flag.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read!(authorize?: false)

      admin_row = Enum.find(all_assignments, &(&1.user_id == admin.id))
      assert admin_row.cleared_at
    end
  end
end
