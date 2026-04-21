defmodule IntellisparkWeb.HighFiveViewLiveTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures
  import Intellispark.RecognitionFixtures

  alias Intellispark.Recognition.HighFive

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "valid token renders branded page", %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Chris", last_name: "Adams"})

    hf =
      send_high_five!(admin, school, student, %{
        title: "Great effort",
        body: "Keep going!",
        recipient_email: "chris@example.com"
      })

    {:ok, _lv, html} = live(conn, ~p"/high-fives/#{hf.token}")

    assert html =~ "Great effort"
    assert html =~ "Keep going!"
    assert html =~ "you got a High 5!"
  end

  test "unknown token renders link-expired fallback", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/high-fives/garbage-token-123")

    assert html =~ "Link expired"
  end

  test "view_count increments after WebSocket connect", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    student = create_student!(school, %{first_name: "Kara", last_name: "Via"})

    hf =
      send_high_five!(admin, school, student, %{
        title: "Thanks",
        body: "for being great",
        recipient_email: "kara@example.com"
      })

    assert hf.view_count == 0

    {:ok, _lv, _html} = live(conn, ~p"/high-fives/#{hf.token}")

    fresh = Ash.get!(HighFive, hf.id, tenant: school.id, authorize?: false)
    assert fresh.view_count == 1
    assert fresh.first_viewed_at != nil
  end
end
