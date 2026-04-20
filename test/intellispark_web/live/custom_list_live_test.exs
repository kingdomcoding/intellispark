defmodule IntellisparkWeb.CustomListLiveTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures

  alias Intellispark.Students.CustomList

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  describe "/lists" do
    test "signed-out redirects to /sign-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/lists")
    end

    test "shows All Students card + owner's lists", %{
      conn: conn,
      school: school,
      admin: admin
    } do
      create_custom_list!(admin, school, %{name: "G9 IEPs"})

      {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/lists")

      assert html =~ "My Lists"
      assert html =~ "All Students"
      assert html =~ "G9 IEPs"
    end

    test "hides private lists from other users", %{
      conn: conn,
      school: school,
      admin: admin
    } do
      create_custom_list!(admin, school, %{name: "Admin-Private", shared?: false})

      peer =
        Ash.create!(
          Intellispark.Accounts.User,
          %{
            email: "peer-lists@sandbox.edu",
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

      peer = Ash.load!(peer, [school_memberships: [:school]], authorize?: false)

      {:ok, _lv, html} = conn |> log_in_user(peer) |> live(~p"/lists")
      refute html =~ "Admin-Private"
    end
  end

  describe "/lists/:id" do
    test "clicking a student row carries return_to back to the list", %{
      conn: conn,
      school: school,
      admin: admin
    } do
      tag = create_tag!(school, %{name: "Return-Target"})
      s = create_student!(school, %{first_name: "Back", last_name: "Me"})
      apply_tag!(admin, school, s, tag)

      {:ok, list} =
        Ash.create(
          CustomList,
          %{name: "RT", filters: %{tag_ids: [tag.id]}},
          tenant: school.id,
          actor: admin,
          authorize?: true
        )

      {:ok, _lv, html} =
        conn |> log_in_user(admin) |> live(~p"/students/#{s.id}?return_to=/lists/#{list.id}")

      assert html =~ "Back to RT"
      assert html =~ "/lists/#{list.id}"
    end

    test "renders only students matching the saved filter", %{
      conn: conn,
      school: school,
      admin: admin
    } do
      tag = create_tag!(school, %{name: "Target"})
      matching = create_student!(school, %{first_name: "Match", last_name: "Me"})
      _other = create_student!(school, %{first_name: "Skip", last_name: "Me"})
      apply_tag!(admin, school, matching, tag)

      {:ok, list} =
        Ash.create(
          CustomList,
          %{name: "Tagged", filters: %{tag_ids: [tag.id]}},
          tenant: school.id,
          actor: admin,
          authorize?: true
        )

      {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/lists/#{list.id}")

      assert html =~ "Match Me"
      refute html =~ "Skip Me"
    end
  end
end
