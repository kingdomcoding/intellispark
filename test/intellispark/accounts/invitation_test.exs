defmodule Intellispark.Accounts.InvitationTest do
  use Intellispark.DataCase, async: false

  import Swoosh.TestAssertions

  require Ash.Query

  alias Intellispark.Accounts
  alias Intellispark.Accounts.{District, School, SchoolInvitation, User, UserSchoolMembership}

  setup do
    {:ok, district} =
      Ash.create(District, %{name: "Sandbox", slug: "sandbox"}, authorize?: false)

    {:ok, school} =
      Ash.create(
        School,
        %{name: "Sandbox High", slug: "sh", district_id: district.id},
        authorize?: false
      )

    admin =
      register!("admin@sandbox.edu", "supersecret123")
      |> attach_district!(district.id)
      |> with_membership!(school.id, :admin)

    teacher =
      register!("teacher@sandbox.edu", "supersecret123")
      |> attach_district!(district.id)
      |> with_membership!(school.id, :teacher)

    %{district: district, school: school, admin: admin, teacher: teacher}
  end

  describe "invite" do
    test "admin creates an invitation and an email gets sent", %{admin: admin, school: school} do
      # Drain confirmation emails sent as a side-effect of registering the
      # admin and teacher fixtures in setup — we only care about the
      # invitation email here.
      drain_mailbox()

      assert {:ok, invite} =
               Accounts.invite_to_school("alice@sandbox.edu", school.id, :teacher, actor: admin)

      assert to_string(invite.email) == "alice@sandbox.edu"
      assert invite.role == :teacher
      assert invite.status == :pending
      assert invite.inviter_id == admin.id
      assert DateTime.compare(invite.expires_at, DateTime.utc_now()) == :gt

      assert_email_sent(to: "alice@sandbox.edu")
    end

    test "non-admin actor is forbidden", %{teacher: teacher, school: school} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.invite_to_school("bob@sandbox.edu", school.id, :teacher, actor: teacher)
    end

    test "nil actor is forbidden", %{school: school} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.invite_to_school("bob@sandbox.edu", school.id, :teacher, actor: nil)
    end

    test "admin from a different district cannot invite into this school",
         %{school: school} do
      {:ok, other_district} =
        Ash.create(District, %{name: "Other", slug: "other"}, authorize?: false)

      {:ok, other_school} =
        Ash.create(
          School,
          %{name: "Other High", slug: "oh", district_id: other_district.id},
          authorize?: false
        )

      stranger =
        register!("stranger@other.edu", "supersecret123")
        |> attach_district!(other_district.id)
        |> with_membership!(other_school.id, :admin)

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.invite_to_school("charlie@sandbox.edu", school.id, :teacher,
                 actor: stranger
               )
    end

    test "duplicate pending invite for same email+school is rejected by identity",
         %{admin: admin, school: school} do
      {:ok, _} =
        Accounts.invite_to_school("dup@sandbox.edu", school.id, :teacher, actor: admin)

      assert {:error, %Ash.Error.Invalid{}} =
               Accounts.invite_to_school("dup@sandbox.edu", school.id, :teacher, actor: admin)
    end
  end

  describe "accept_by_token" do
    test "accepting creates user + membership + marks invitation accepted",
         %{admin: admin, school: school} do
      {:ok, invite} =
        Accounts.invite_to_school("alice@sandbox.edu", school.id, :teacher, actor: admin)

      assert {:ok, accepted} =
               Accounts.accept_school_invitation(
                 invite,
                 "newpass123!",
                 "newpass123!",
                 "Alice",
                 nil,
                 authorize?: false
               )

      assert accepted.status == :accepted
      assert accepted.accepted_at != nil

      user = accepted.__metadata__.user
      assert to_string(user.email) == "alice@sandbox.edu"
      assert user.first_name == "Alice"

      {:ok, [membership]} =
        UserSchoolMembership
        |> Ash.Query.filter(user_id: user.id)
        |> Ash.read(authorize?: false)

      assert membership.school_id == school.id
      assert membership.role == :teacher
      assert membership.source == :invitation
    end

    test "existing user accept: no new user row, membership added",
         %{admin: admin, school: school, teacher: teacher} do
      # Teacher already has a membership to `school`. Invite them again to a
      # new school to exercise the existing-user branch.
      {:ok, second_school} =
        Ash.create(
          School,
          %{name: "Second HS", slug: "sh2", district_id: school.district_id},
          authorize?: false
        )

      {:ok, invite} =
        Accounts.invite_to_school(to_string(teacher.email), second_school.id, :counselor,
          actor: admin
        )

      users_before = User |> Ash.count!(authorize?: false)

      assert {:ok, accepted} =
               Accounts.accept_school_invitation(
                 invite,
                 "unused",
                 "unused",
                 nil,
                 nil,
                 authorize?: false
               )

      users_after = User |> Ash.count!(authorize?: false)
      assert users_after == users_before
      assert accepted.__metadata__.user.id == teacher.id

      {:ok, memberships} =
        UserSchoolMembership
        |> Ash.Query.filter(user_id: teacher.id)
        |> Ash.read(authorize?: false)

      assert Enum.any?(memberships, &(&1.school_id == second_school.id))
    end

    test "expired invitation is rejected", %{admin: admin, school: school} do
      {:ok, invite} =
        Accounts.invite_to_school("late@sandbox.edu", school.id, :teacher, actor: admin)

      # Time-travel the row's expires_at into the past via raw Ecto — the
      # resource doesn't expose a generic update action and we don't want
      # to add a test-only one.
      Intellispark.Repo.query!(
        "UPDATE school_invitations SET expires_at = $1 WHERE id = $2::uuid",
        [DateTime.add(DateTime.utc_now(), -1, :day), Ecto.UUID.dump!(invite.id)]
      )

      expired = Ash.get!(SchoolInvitation, invite.id, authorize?: false)

      assert {:error, _} =
               Accounts.accept_school_invitation(
                 expired,
                 "pw123456!",
                 "pw123456!",
                 nil,
                 nil,
                 authorize?: false
               )
    end

    test "revoked invitation cannot be accepted", %{admin: admin, school: school} do
      {:ok, invite} =
        Accounts.invite_to_school("ghost@sandbox.edu", school.id, :teacher, actor: admin)

      {:ok, revoked} =
        Accounts.revoke_school_invitation(invite, actor: admin)

      assert {:error, _} =
               Accounts.accept_school_invitation(
                 revoked,
                 "pw123456!",
                 "pw123456!",
                 nil,
                 nil,
                 authorize?: false
               )
    end

    test "double-accept is rejected", %{admin: admin, school: school} do
      {:ok, invite} =
        Accounts.invite_to_school("twice@sandbox.edu", school.id, :teacher, actor: admin)

      {:ok, accepted} =
        Accounts.accept_school_invitation(
          invite,
          "pw123456!",
          "pw123456!",
          nil,
          nil,
          authorize?: false
        )

      assert accepted.status == :accepted

      assert {:error, _} =
               Accounts.accept_school_invitation(
                 accepted,
                 "pw123456!",
                 "pw123456!",
                 nil,
                 nil,
                 authorize?: false
               )
    end
  end

  describe "revoke" do
    test "admin can revoke a pending invite", %{admin: admin, school: school} do
      {:ok, invite} =
        Accounts.invite_to_school("will-revoke@sandbox.edu", school.id, :teacher,
          actor: admin
        )

      assert {:ok, revoked} = Accounts.revoke_school_invitation(invite, actor: admin)
      assert revoked.status == :revoked
    end

    test "non-admin cannot revoke", %{admin: admin, teacher: teacher, school: school} do
      {:ok, invite} =
        Accounts.invite_to_school("hands-off@sandbox.edu", school.id, :teacher,
          actor: admin
        )

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.revoke_school_invitation(invite, actor: teacher)
    end
  end

  describe "paper trail" do
    test "invitation create + accept produce version records",
         %{admin: admin, school: school} do
      {:ok, invite} =
        Accounts.invite_to_school("audit@sandbox.edu", school.id, :teacher, actor: admin)

      {:ok, _accepted} =
        Accounts.accept_school_invitation(
          invite,
          "pw123456!",
          "pw123456!",
          nil,
          nil,
          authorize?: false
        )

      {:ok, versions} =
        SchoolInvitation.Version
        |> Ash.Query.filter(version_source_id == ^invite.id)
        |> Ash.read(authorize?: false)

      actions = Enum.map(versions, & &1.version_action_name) |> Enum.sort()
      assert :accept_by_token in actions
      assert :invite in actions
    end
  end

  defp drain_mailbox do
    receive do
      {:email, _email} -> drain_mailbox()
    after
      0 -> :ok
    end
  end

  defp register!(email, password) do
    Ash.create!(
      User,
      %{email: email, password: password, password_confirmation: password},
      action: :register_with_password,
      authorize?: false
    )
  end

  defp attach_district!(user, district_id) do
    Ash.update!(user, %{district_id: district_id}, action: :set_district, authorize?: false)
  end

  defp with_membership!(user, school_id, role) do
    {:ok, _} =
      Ash.create(
        UserSchoolMembership,
        %{user_id: user.id, school_id: school_id, role: role, source: :manual},
        authorize?: false
      )

    Ash.load!(user, [school_memberships: [:school]], authorize?: false)
  end
end
