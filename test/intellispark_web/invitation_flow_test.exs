defmodule IntellisparkWeb.InvitationFlowTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  require Ash.Query

  alias Intellispark.Accounts
  alias Intellispark.Accounts.{District, School, SchoolInvitation, User, UserSchoolMembership}

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)

    {:ok, district} =
      Ash.create(District, %{name: "Sandbox", slug: "sandbox"}, authorize?: false)

    {:ok, school} =
      Ash.create(
        School,
        %{name: "Sandbox High", slug: "sh", district_id: district.id},
        authorize?: false
      )

    admin = register_user!("admin@sandbox.edu", "supersecret123")
    admin = attach_district!(admin, district.id)
    admin = with_membership!(admin, school.id, :admin)

    %{district: district, school: school, admin: admin}
  end

  describe "GET /invitations/:token" do
    test "pending invite shows the accept form", %{conn: conn, admin: admin, school: school} do
      {:ok, invite} =
        Accounts.invite_to_school("alice@sandbox.edu", school.id, :teacher, actor: admin)

      {:ok, _lv, html} = live(conn, ~p"/invitations/#{invite.id}")

      assert html =~ "Welcome to Intellispark"
      assert html =~ "Sandbox High"
      assert html =~ "teacher"
      assert html =~ "alice@sandbox.edu"
      assert html =~ "Accept"
    end

    test "accepted invite shows the already-accepted state",
         %{conn: conn, admin: admin, school: school} do
      {:ok, invite} =
        Accounts.invite_to_school("already@sandbox.edu", school.id, :teacher, actor: admin)

      {:ok, _} =
        Accounts.accept_school_invitation(
          invite,
          "newpass123!",
          "newpass123!",
          nil,
          nil,
          authorize?: false
        )

      {:ok, _lv, html} = live(conn, ~p"/invitations/#{invite.id}")
      assert html =~ "Already accepted"
    end

    test "revoked invite shows the revoked state",
         %{conn: conn, admin: admin, school: school} do
      {:ok, invite} =
        Accounts.invite_to_school("gone@sandbox.edu", school.id, :teacher, actor: admin)

      {:ok, _} = Accounts.revoke_school_invitation(invite, actor: admin)

      {:ok, _lv, html} = live(conn, ~p"/invitations/#{invite.id}")
      assert html =~ "Invitation cancelled"
    end

    test "malformed id renders the friendly invalid state", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/invitations/not-a-uuid")
      assert html =~ "Link invalid or expired"
    end

    test "unknown id renders the friendly invalid state", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/invitations/00000000-0000-0000-0000-000000000000")

      assert html =~ "Link invalid or expired"
    end
  end

  describe "form submit" do
    test "accepting creates user + membership and redirects to sign_in_with_token",
         %{conn: conn, admin: admin, school: school} do
      {:ok, invite} =
        Accounts.invite_to_school("bob@sandbox.edu", school.id, :counselor, actor: admin)

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invite.id}")

      form_params = %{
        "user" => %{
          "first_name" => "Bob",
          "last_name" => "Smith",
          "password" => "new-bob-pass-123",
          "password_confirmation" => "new-bob-pass-123"
        }
      }

      assert {:error, {:redirect, %{to: to}}} =
               lv
               |> form("#accept-form", form_params)
               |> render_submit()

      assert to =~ "/auth/user/password/sign_in_with_token"

      {:ok, %User{} = user} =
        User
        |> Ash.Query.filter(email == "bob@sandbox.edu")
        |> Ash.read_one(authorize?: false)

      assert user.first_name == "Bob"

      {:ok, [membership]} =
        UserSchoolMembership
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read(authorize?: false)

      assert membership.school_id == school.id
      assert membership.role == :counselor
      assert membership.source == :invitation

      updated_invite = Ash.get!(SchoolInvitation, invite.id, authorize?: false)
      assert updated_invite.status == :accepted
    end

    test "password mismatch keeps the user on the form with an error",
         %{conn: conn, admin: admin, school: school} do
      {:ok, invite} =
        Accounts.invite_to_school("mismatch@sandbox.edu", school.id, :teacher, actor: admin)

      {:ok, lv, _html} = live(conn, ~p"/invitations/#{invite.id}")

      html =
        lv
        |> form("#accept-form", %{
          "user" => %{
            "password" => "one",
            "password_confirmation" => "two",
            "first_name" => nil,
            "last_name" => nil
          }
        })
        |> render_submit()

      assert html =~ "Accept"
      # Invitation still pending — form submit didn't mutate state.
      invitation = Ash.get!(SchoolInvitation, invite.id, authorize?: false)
      assert invitation.status == :pending

      {:ok, nil} =
        User
        |> Ash.Query.filter(email == "mismatch@sandbox.edu")
        |> Ash.read_one(authorize?: false)
    end
  end

  defp register_user!(email, password) do
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
