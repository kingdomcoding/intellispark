defmodule IntellisparkWeb.TeamBulkModalTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures
  import Intellispark.TeamsFixtures

  require Ash.Query

  alias Intellispark.Teams.TeamMembership

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "toolbar team icon opens the bulk modal with the correct student count", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    _staff = register_staff!(school, :counselor)

    s1 = create_student!(school, %{first_name: "Alpha"})
    s2 = create_student!(school, %{first_name: "Beta"})

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students")

    lv
    |> element("input[phx-click='toggle_select'][phx-value-id='#{s1.id}']")
    |> render_click()

    lv
    |> element("input[phx-click='toggle_select'][phx-value-id='#{s2.id}']")
    |> render_click()

    html =
      lv
      |> element("button[phx-value-action='team']")
      |> render_click()

    assert html =~ "Assign a team member to 2 students"
    assert html =~ "Staff person"
    assert html =~ "Role"
  end

  test "submit bulk_add creates TeamMembership rows", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    staff = register_staff!(school, :counselor)

    s1 = create_student!(school, %{first_name: "Gamma"})
    s2 = create_student!(school, %{first_name: "Delta"})

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students")

    for sid <- [s1.id, s2.id] do
      lv
      |> element("input[phx-click='toggle_select'][phx-value-id='#{sid}']")
      |> render_click()
    end

    _ =
      lv
      |> element("button[phx-value-action='team']")
      |> render_click()

    _ =
      lv
      |> form("#bulk-team form", %{"user_id" => staff.id, "role" => "coach"})
      |> render_submit()

    rows =
      TeamMembership
      |> Ash.Query.filter(user_id == ^staff.id and role == :coach)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)

    student_ids = Enum.map(rows, & &1.student_id) |> Enum.sort()
    assert student_ids == Enum.sort([s1.id, s2.id])
  end
end
