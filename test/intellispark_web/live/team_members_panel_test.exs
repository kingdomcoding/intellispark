defmodule IntellisparkWeb.TeamMembersPanelTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures
  import Intellispark.TeamsFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "empty state renders all three role groups", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Empty", last_name: "Team"})

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "Team members"
    assert html =~ "Current Teachers"
    assert html =~ "Family"
    assert html =~ "Other Staff"
  end

  test "renders members under the right role groups", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Full", last_name: "Team"})
    teacher = register_staff!(school, :teacher)
    family = register_staff!(school, :teacher)
    coach = register_staff!(school, :counselor)

    _ = create_team_membership!(admin, school, student, teacher, :teacher)
    _ = create_team_membership!(admin, school, student, family, :family)
    _ = create_team_membership!(admin, school, student, coach, :coach)

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "Team members (3)"
  end

  test "+ Team member button opens the modal", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Modal", last_name: "Open"})

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    html = lv |> element("button", "+ Team member") |> render_click()

    assert html =~ "New team member"
    assert html =~ "Family / community members"
    assert html =~ "School staff"
  end
end
