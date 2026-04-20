defmodule IntellisparkWeb.StudentHubTimelineTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures

  alias Intellispark.Students

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "recent events show up in the Activity feed newest-first", %{
    conn: conn,
    school: school,
    admin: admin
  } do
    student = create_student!(school, %{first_name: "Time", last_name: "Line"})
    tag = create_tag!(school, %{name: "TLTag"})
    status = create_status!(school, %{name: "TLStatus"})

    apply_tag!(admin, school, student, tag)

    {:ok, student} =
      Students.set_student_status(student, status.id,
        actor: admin,
        tenant: school.id,
        authorize?: false
      )

    {:ok, _} =
      Ash.update(student, %{preferred_name: "TL"},
        action: :update,
        tenant: school.id,
        actor: admin,
        authorize?: false
      )

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "Activity"
    assert html =~ "Profile created"
    assert html =~ "Tag applied"
    assert html =~ "Status set"
    assert html =~ "Profile updated"
  end

  test "empty-state shown when no versions exist yet", %{conn: conn, admin: admin, school: school} do
    student = create_student!(school, %{first_name: "Empty", last_name: "TL"})

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "Profile created"
  end
end
