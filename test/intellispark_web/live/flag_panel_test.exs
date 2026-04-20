defmodule IntellisparkWeb.FlagPanelTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures
  import Intellispark.FlagsFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "empty-state when the student has no flags", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Empty", last_name: "Flag"})

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "No open flags for this student"
  end

  test "lists an open flag + excludes closed ones", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Listed", last_name: "Flag"})
    type_open = create_flag_type!(school, %{name: "Academic-PL1"})
    type_closed = create_flag_type!(school, %{name: "Academic-PL2"})

    flag_open = create_flag!(admin, school, student, type_open)
    _opened = open_flag!(flag_open, [admin.id], admin)

    flag_to_close = create_flag!(admin, school, student, type_closed)
    opened2 = open_flag!(flag_to_close, [admin.id], admin)
    _closed = close_flag!(opened2, "done", admin)

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "Academic-PL1"
    refute html =~ "Academic-PL2"
  end
end
