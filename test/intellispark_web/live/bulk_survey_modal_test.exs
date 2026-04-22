defmodule IntellisparkWeb.BulkSurveyModalTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.AssessmentsFixtures
  import Intellispark.StudentsFixtures

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    %{school: school, admin: admin} = world = setup_world()

    template = create_template!(school, %{name: "Bulk LV Tmpl"})
    create_question!(template, %{prompt: "Q1", required?: false})
    published = publish_template!(template, admin)

    Map.merge(
      %{conn: Phoenix.ConnTest.build_conn(), template: published},
      world
    )
  end

  test "selecting rows + clicking forms icon opens the bulk modal",
       %{conn: conn, school: school, admin: admin} do
    s1 = create_student!(school, %{first_name: "Alice", email: "a@example.com"})
    _ = create_student!(school, %{first_name: "Bob"})

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students")

    lv
    |> element("input[phx-click='toggle_select'][phx-value-id='#{s1.id}']")
    |> render_click()

    html =
      lv
      |> element("button[phx-value-action='forms']")
      |> render_click()

    assert html =~ "Assign a survey to"
    assert html =~ "Bulk LV Tmpl"
  end

  test "skip_if_previously_assigned excludes students with any prior assignment",
       %{conn: conn, school: school, admin: admin, template: template} do
    done = create_student!(school, %{first_name: "Done"})
    fresh = create_student!(school, %{first_name: "Fresh"})

    a = assign_survey!(admin, school, done, template)
    _ = submit!(a)

    before_count =
      list_assignments_for_student(school, done) |> length()

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students")

    for s <- [done, fresh] do
      lv
      |> element("input[phx-click='toggle_select'][phx-value-id='#{s.id}']")
      |> render_click()
    end

    _ =
      lv
      |> element("button[phx-value-action='forms']")
      |> render_click()

    _ =
      lv
      |> element("#bulk-forms form")
      |> render_submit(%{"template_id" => template.id, "mode" => "skip_if_previously_assigned"})

    _ = :sys.get_state(lv.pid)

    assert list_assignments_for_student(school, done) |> length() == before_count
    assert list_assignments_for_student(school, fresh) |> length() == 1
  end

  test "assign_regardless creates an assignment even for previously-submitted students",
       %{conn: conn, school: school, admin: admin, template: template} do
    done = create_student!(school, %{first_name: "Done2"})
    a = assign_survey!(admin, school, done, template)
    _ = submit!(a)

    before_count = list_assignments_for_student(school, done) |> length()

    {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/students")

    lv
    |> element("input[phx-click='toggle_select'][phx-value-id='#{done.id}']")
    |> render_click()

    _ =
      lv
      |> element("button[phx-value-action='forms']")
      |> render_click()

    _ =
      lv
      |> element("#bulk-forms form")
      |> render_submit(%{"template_id" => template.id, "mode" => "assign_regardless"})

    _ = :sys.get_state(lv.pid)

    assert list_assignments_for_student(school, done) |> length() == before_count + 1
  end
end
