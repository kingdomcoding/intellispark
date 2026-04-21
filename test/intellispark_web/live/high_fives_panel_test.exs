defmodule IntellisparkWeb.HighFivesPanelTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures
  import Intellispark.RecognitionFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "empty state when no high 5s", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "None", last_name: "Here"})

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "No High 5&#39;s yet"
  end

  test "lists seeded high 5 card", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Has", last_name: "One"})

    _ =
      send_high_five!(admin, school, student, %{
        title: "Outstanding",
        body: "You were amazing.",
        recipient_email: "x@example.com"
      })

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "Outstanding"
    assert html =~ "You were amazing."
  end

  test "+ High 5 opens the new modal", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Modal", last_name: "Open"})

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    html = lv |> element("button", "+ High 5") |> render_click()
    assert html =~ "New High 5 for"
    assert html =~ "Title"
  end
end
