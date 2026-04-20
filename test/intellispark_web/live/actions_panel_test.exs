defmodule IntellisparkWeb.ActionsPanelTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures
  import Intellispark.SupportFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "empty-state when no pending actions", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "NoActions", last_name: "Hi"})

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "No open actions for this student"
  end

  test "lists pending action with due date + assignee", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    student = create_student!(school, %{first_name: "HasActions", last_name: "Due"})

    _ =
      create_action!(admin, school, student, admin, %{
        description: "follow up with parents",
        due_on: Date.utc_today()
      })

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "Action needed (1)"
    assert html =~ "follow up with parents"
    assert html =~ admin.email |> to_string()
    assert html =~ "Due "
  end

  test "clicking checkbox completes the action and row drops", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    student = create_student!(school, %{first_name: "Complete", last_name: "Me"})

    action =
      create_action!(admin, school, student, admin, %{description: "bang the gong"})

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    lv
    |> element("#action-#{action.id} input[type='checkbox']")
    |> render_click()

    html = render(lv)
    refute html =~ "bang the gong"
    assert html =~ "No open actions for this student"
  end

  test "+ Action opens the new-action modal", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "ModalOpen", last_name: "X"})

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    html = lv |> element("button", "+ Action") |> render_click()
    assert html =~ "New action for"
    assert html =~ "What needs to happen?"
  end
end
