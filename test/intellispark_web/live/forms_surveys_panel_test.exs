defmodule IntellisparkWeb.FormsSurveysPanelTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.AssessmentsFixtures
  import Intellispark.StudentsFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    world = setup_world()
    template = create_template!(world.school, %{name: "Hub Tmpl"})
    create_question!(template, %{prompt: "Q1", required?: false})
    published = publish_template!(template, world.admin)

    Map.merge(
      %{conn: Phoenix.ConnTest.build_conn(), template: published},
      world
    )
  end

  test "shows empty state when no assignments",
       %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Empty", last_name: "Hub"})

    {:ok, _lv, html} =
      conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "Forms &amp; Surveys"
    assert html =~ "No forms assigned yet."
  end

  test "lists submitted assignment with Completed on text",
       %{conn: conn, school: school, admin: admin, template: template} do
    student = create_student!(school, %{first_name: "Done", last_name: "Survey"})
    a = assign_survey!(admin, school, student, template)
    submitted = submit!(a)

    {:ok, _lv, html} =
      conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "Hub Tmpl"
    assert html =~ "Completed on"
    assert html =~ Calendar.strftime(submitted.submitted_at, "%b")
  end

  test "+ Form assignment opens the new modal",
       %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Open", last_name: "Modal"})

    {:ok, lv, _html} =
      conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    html = lv |> element("button", "+ Form assignment") |> render_click()
    assert html =~ "New form assignment"
    assert html =~ "Select form to assign"
  end

  test "submitting modal creates assignment row + flash",
       %{conn: conn, school: school, admin: admin, template: template} do
    student = create_student!(school, %{first_name: "Make", last_name: "Assignment"})

    {:ok, lv, _html} =
      conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    _ = lv |> element("button", "+ Form assignment") |> render_click()

    _ =
      lv
      |> element("#new-survey-modal form")
      |> render_submit(%{"template_id" => template.id})

    _ = :sys.get_state(lv.pid)
    html = render(lv)

    assert html =~ "Form assigned."
    assert html =~ "Hub Tmpl"
  end
end
