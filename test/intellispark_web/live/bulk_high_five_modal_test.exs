defmodule IntellisparkWeb.BulkHighFiveModalTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures
  import Intellispark.RecognitionFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "toolbar icon opens bulk modal after selection", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    _ = create_template!(school, %{title: "Pick me"})

    s1 = create_student!(school, %{first_name: "A", email: "a@example.com"})
    _s2 = create_student!(school, %{first_name: "B", email: "b@example.com"})

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students")

    lv
    |> element("input[phx-click='toggle_select'][phx-value-id='#{s1.id}']")
    |> render_click()

    html =
      lv
      |> element("button[phx-value-action='high_fives']")
      |> render_click()

    assert html =~ "Send a High 5 to"
    assert html =~ "Pick me"
  end
end
