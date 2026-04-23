defmodule IntellisparkWeb.StudentLive.LifecycleTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "archive flow: menu click opens modal, confirm archives and redirects", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    student = create_student!(school, %{first_name: "Arch", last_name: "Flow"})

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    lv
    |> render_hook("student_action_attempt", %{"action" => "archive"})

    assert render(lv) =~ "Archive Arch Flow?"

    result =
      lv
      |> element("button[phx-click=\"confirm_archive\"]")
      |> render_click()

    assert {:error, {:live_redirect, %{to: "/students"}}} = result

    visible =
      Intellispark.Students.list_students!(tenant: school.id, authorize?: false)
      |> Enum.map(& &1.id)

    refute student.id in visible
  end
end
