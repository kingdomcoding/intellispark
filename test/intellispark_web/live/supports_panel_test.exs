defmodule IntellisparkWeb.SupportsPanelTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures
  import Intellispark.SupportFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "empty-state when no supports", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "NoSup", last_name: "Empty"})

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "No supports in progress"
  end

  test "lists offered + in_progress, excludes completed + declined", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    student = create_student!(school, %{first_name: "Mixed", last_name: "Supports"})

    _offered = create_support!(admin, school, student, %{title: "Offered Plan"})
    completed = create_support!(admin, school, student, %{title: "Completed Plan"})
    _ = completed |> accept_support!(admin) |> complete_support!(admin)
    declined = create_support!(admin, school, student, %{title: "Declined Plan"})
    _ = decline_support!(declined, admin, "nope")

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "Offered Plan"
    refute html =~ "Completed Plan"
    refute html =~ "Declined Plan"
  end

  test "clicking row opens detail sheet with Accept / Decline for offered", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    student = create_student!(school, %{first_name: "OpenSheet", last_name: "Now"})
    support = create_support!(admin, school, student, %{title: "Detail Sheet"})

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    html = lv |> element("#support-#{support.id}") |> render_click()

    assert html =~ "Detail Sheet"
    assert html =~ "Accept"
    assert html =~ "Decline"
  end
end
