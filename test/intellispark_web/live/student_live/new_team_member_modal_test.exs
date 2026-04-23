defmodule IntellisparkWeb.StudentLive.NewTeamMemberModalTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures
  import Intellispark.TeamsFixtures

  require Ash.Query

  alias Intellispark.Teams.{ExternalPerson, KeyConnection, TeamMembership}

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  defp open_modal(conn, admin, student) do
    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    lv
    |> element("button[phx-click=\"open_new_team_member_modal\"]")
    |> render_click()

    lv
  end

  describe "menu" do
    test "renders both top-level options", %{conn: conn, school: school, admin: admin} do
      student = create_student!(school, %{first_name: "Menu", last_name: "Test"})
      lv = open_modal(conn, admin, student)
      html = render(lv)

      assert html =~ "Family / community members"
      assert html =~ "School staff"
    end
  end

  describe "family flow" do
    test "drill-in lists existing external persons + create-new button", %{
      conn: conn,
      school: school,
      admin: admin
    } do
      _ep =
        create_external_person!(admin, school, %{
          first_name: "Renee",
          last_name: "Walker",
          relationship_kind: :parent
        })

      student = create_student!(school, %{first_name: "Drill", last_name: "In"})
      lv = open_modal(conn, admin, student)

      html =
        lv
        |> element(~s|button[phx-value-view="family"]|)
        |> render_click()

      assert html =~ "Renee"
      assert html =~ "Walker"
      assert html =~ "+ Add new family/community contact"
    end

    test "picking an existing external person creates a KeyConnection + closes modal",
         %{conn: conn, school: school, admin: admin} do
      ep = create_external_person!(admin, school)
      student = create_student!(school, %{first_name: "Pick", last_name: "Existing"})
      lv = open_modal(conn, admin, student)

      lv |> element(~s|button[phx-value-view="family"]|) |> render_click()
      lv |> element(~s|button[phx-value-id="#{ep.id}"]|) |> render_click()

      assert {:ok, [kc]} =
               KeyConnection
               |> Ash.Query.filter(student_id == ^student.id)
               |> Ash.Query.set_tenant(school.id)
               |> Ash.read(authorize?: false)

      assert kc.connected_external_person_id == ep.id
      assert is_nil(kc.connected_user_id)
      refute render(lv) =~ ~s(id="new-team-member-modal")
    end

    test "creating a new contact creates ExternalPerson + KeyConnection in one flow",
         %{conn: conn, school: school, admin: admin} do
      student = create_student!(school, %{first_name: "Brand", last_name: "New"})
      lv = open_modal(conn, admin, student)

      lv |> element(~s|button[phx-value-view="family"]|) |> render_click()
      lv |> element(~s|button[phx-value-view="family_new"]|) |> render_click()

      lv
      |> form(
        "form[phx-submit=\"create_external_person\"]",
        first_name: "Mira",
        last_name: "Patel",
        relationship_kind: "guardian",
        email: "mp@example.com",
        phone: ""
      )
      |> render_submit()

      assert {:ok, [ep]} =
               ExternalPerson
               |> Ash.Query.filter(first_name == "Mira" and last_name == "Patel")
               |> Ash.Query.set_tenant(school.id)
               |> Ash.read(authorize?: false)

      assert ep.relationship_kind == :guardian
      assert ep.email == "mp@example.com"

      assert {:ok, [_kc]} =
               KeyConnection
               |> Ash.Query.filter(connected_external_person_id == ^ep.id)
               |> Ash.Query.set_tenant(school.id)
               |> Ash.read(authorize?: false)
    end
  end

  describe "staff flow" do
    test "searchable list narrows when query is typed", %{
      conn: conn,
      school: school,
      admin: admin
    } do
      _staff_a = register_staff!(school, :counselor)
      student = create_student!(school, %{first_name: "Search", last_name: "Staff"})
      lv = open_modal(conn, admin, student)

      lv |> element(~s|button[phx-value-view="staff"]|) |> render_click()

      html =
        lv
        |> form("form[phx-change=\"search_staff\"]", %{"q" => "no_match_for_anyone"})
        |> render_change()

      assert html =~ "No matching staff."
    end

    test "multi-select + add creates one TeamMembership per selected staff",
         %{conn: conn, school: school, admin: admin} do
      staff_a = register_staff!(school, :counselor)
      staff_b = register_staff!(school, :counselor)
      student = create_student!(school, %{first_name: "Multi", last_name: "Add"})

      lv = open_modal(conn, admin, student)
      lv |> element(~s|button[phx-value-view="staff"]|) |> render_click()

      lv
      |> element(~s|input[phx-click="toggle_staff"][phx-value-id="#{staff_a.id}"]|)
      |> render_click()

      lv
      |> element(~s|input[phx-click="toggle_staff"][phx-value-id="#{staff_b.id}"]|)
      |> render_click()

      lv
      |> element(~s|button[phx-click="add_selected_staff"]|)
      |> render_click()

      {:ok, memberships} =
        TeamMembership
        |> Ash.Query.filter(student_id == ^student.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read(authorize?: false)

      uids = Enum.map(memberships, & &1.user_id) |> Enum.sort()
      assert Enum.sort([staff_a.id, staff_b.id]) == uids
    end
  end

  describe "back navigation" do
    test "← Back returns to menu from sub-views", %{
      conn: conn,
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Back", last_name: "Btn"})
      lv = open_modal(conn, admin, student)

      lv |> element(~s|button[phx-value-view="staff"]|) |> render_click()
      html = lv |> element(~s|button[phx-value-view="menu"]|) |> render_click()
      assert html =~ "Family / community members"
    end
  end
end
