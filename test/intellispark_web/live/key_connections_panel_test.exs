defmodule IntellisparkWeb.KeyConnectionsPanelTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures
  import Intellispark.TeamsFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "empty state", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Empty", last_name: "Conn"})

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "No connections added yet."
  end

  test "seeded connections render with note", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Has", last_name: "Conn"})
    staff_a = register_staff!(school, :counselor)
    staff_b = register_staff!(school, :counselor)

    _ =
      create_key_connection!(admin, school, student, staff_a, %{
        note: "co-captain since freshman year"
      })

    _ =
      create_key_connection!(admin, school, student, staff_b, %{
        source: :self_reported,
        note: "self-reported on Insightfull"
      })

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "co-captain since freshman year"
    assert html =~ "self-reported on Insightfull"
  end

  test "+ Connection button opens the modal", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Modal", last_name: "Conn"})

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    html = lv |> element("button", "+ Connection") |> render_click()

    assert html =~ "New connection"
    assert html =~ "Connected staff"
  end
end
