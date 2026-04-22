defmodule IntellisparkWeb.HubTabsTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures
  import Intellispark.FlagsFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "Profile tab is active by default", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school)

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ ~r/border-brand[^"]*"[^>]*>\s*<span[^>]*hero-user-circle/
    assert html =~ "Profile"
  end

  test "?tab=flag:<id> opens the flag pane",
       %{conn: conn, school: school, admin: admin} do
    student = create_student!(school)
    type = create_flag_type!(school, %{name: "Internet"})
    flag = create_flag!(admin, school, student, type, %{description: "no internet"})

    {:ok, _lv, html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/students/#{student.id}?tab=flag:#{flag.id}")

    assert html =~ "Flag detail"
    assert html =~ "Internet"
  end

  test "clicking a flag patches the URL + opens the tab",
       %{conn: conn, school: school, admin: admin} do
    student = create_student!(school)
    type = create_flag_type!(school)
    flag = create_flag!(admin, school, student, type)
    _opened = open_flag!(flag, [admin.id], admin)

    {:ok, lv, _html} =
      conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    lv
    |> element(~s|li#flag-#{flag.id}|)
    |> render_click()

    assert_patched(lv, "/students/#{student.id}?tab=flag%3A#{flag.id}")
    assert render(lv) =~ "Flag detail"
  end

  test "closing a tab removes it + falls back to Profile",
       %{conn: conn, school: school, admin: admin} do
    student = create_student!(school)
    type = create_flag_type!(school)
    flag = create_flag!(admin, school, student, type)

    {:ok, lv, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/students/#{student.id}?tab=flag:#{flag.id}")

    lv
    |> element(~s|button[phx-click="close_tab"][phx-value-tab="flag:#{flag.id}"]|)
    |> render_click()

    assert_patched(lv, ~p"/students/#{student.id}?tab=profile")
    refute render(lv) =~ "Flag detail"
  end

  test "garbage ?tab= falls back to Profile silently",
       %{conn: conn, school: school, admin: admin} do
    student = create_student!(school)

    {:ok, _lv, html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/students/#{student.id}?tab=banana:notreal")

    assert html =~ "Profile"
    refute html =~ "Flag detail"
  end

  test "PubSub reload preserves @open_tabs",
       %{conn: conn, school: school, admin: admin} do
    student = create_student!(school)
    type = create_flag_type!(school)
    flag = create_flag!(admin, school, student, type)

    {:ok, lv, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/students/#{student.id}?tab=flag:#{flag.id}")

    Phoenix.PubSub.broadcast(
      Intellispark.PubSub,
      "students:#{student.id}",
      %Phoenix.Socket.Broadcast{
        topic: "students:#{student.id}",
        event: "test",
        payload: %{}
      }
    )

    assert render(lv) =~ "Flag detail"
  end
end
