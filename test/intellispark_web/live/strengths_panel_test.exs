defmodule IntellisparkWeb.StrengthsPanelTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures
  import Intellispark.TeamsFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "empty state", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Empty", last_name: "Strg"})

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "No strengths recorded yet."
  end

  test "seeded strengths render in display_order", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Has", last_name: "Strengths"})
    _ = create_strength!(admin, school, student, "Creativity")
    _ = create_strength!(admin, school, student, "Soccer")
    _ = create_strength!(admin, school, student, "Leadership")

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    creativity_idx = :binary.match(html, "Creativity") |> elem(0)
    soccer_idx = :binary.match(html, "Soccer") |> elem(0)
    leadership_idx = :binary.match(html, "Leadership") |> elem(0)

    assert creativity_idx < soccer_idx
    assert soccer_idx < leadership_idx
  end

  test "+ Strength button opens the modal", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Modal", last_name: "Strg"})

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    html = lv |> element("button", "+ Strength") |> render_click()

    assert html =~ "New strength"
  end
end
