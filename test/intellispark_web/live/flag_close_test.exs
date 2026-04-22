defmodule IntellisparkWeb.FlagCloseTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures
  import Intellispark.FlagsFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "close button without a date closes the flag",
       %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "No", last_name: "Date"})
    type = create_flag_type!(school, %{name: "NoDateClose"})
    flag = create_flag!(admin, school, student, type)
    opened = open_flag!(flag, [admin.id], admin)

    {:ok, lv, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/students/#{student.id}?tab=flag:#{opened.id}")

    lv
    |> form("#flag-close-pane-form-#{opened.id}", %{"followup_at" => ""})
    |> render_submit()

    reloaded = Ash.reload!(opened, authorize?: false)
    assert reloaded.status == :closed
    assert reloaded.followup_at == nil
  end

  test "close button with a date sets followup_at",
       %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "With", last_name: "Date"})
    type = create_flag_type!(school, %{name: "WithDateClose"})
    flag = create_flag!(admin, school, student, type)
    opened = open_flag!(flag, [admin.id], admin)
    date_str = Date.utc_today() |> Date.add(14) |> Date.to_iso8601()

    {:ok, lv, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/students/#{student.id}?tab=flag:#{opened.id}")

    lv
    |> form("#flag-close-pane-form-#{opened.id}", %{"followup_at" => date_str})
    |> render_submit()

    reloaded = Ash.reload!(opened, authorize?: false)
    assert reloaded.status == :closed
    assert reloaded.followup_at == Date.from_iso8601!(date_str)
  end
end
