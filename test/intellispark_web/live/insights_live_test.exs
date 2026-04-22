defmodule IntellisparkWeb.InsightsLiveTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures

  alias Intellispark.Indicators

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    world = setup_world()

    s1 = create_student!(world.school, %{first_name: "Alice", last_name: "Adams"})
    s2 = create_student!(world.school, %{first_name: "Bob", last_name: "Brown"})
    s3 = create_student!(world.school, %{first_name: "Carol", last_name: "Chen"})

    {:ok, _} =
      Indicators.upsert_indicator_score(s1.id, :belonging, :low, 2.0, 2, tenant: world.school.id)

    {:ok, _} =
      Indicators.upsert_indicator_score(s2.id, :belonging, :moderate, 3.0, 2,
        tenant: world.school.id
      )

    {:ok, _} =
      Indicators.upsert_indicator_score(s3.id, :belonging, :high, 4.5, 2,
        tenant: world.school.id
      )

    Map.merge(
      %{conn: Phoenix.ConnTest.build_conn(), students: [s1, s2, s3]},
      world
    )
  end

  test "no params — renders 13-dim sidebar with Belonging active (school-wide cohort)",
       %{conn: conn, admin: admin} do
    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/insights")

    assert html =~ "Belonging"
    assert html =~ "Well-Being"
    assert html =~ "Individual Belonging"
    assert html =~ "Belonging summary"
  end

  test "?dimension=well_being preselects that dimension",
       %{conn: conn, admin: admin} do
    {:ok, _lv, html} =
      conn |> log_in_user(admin) |> live(~p"/insights?dimension=well_being")

    assert html =~ "Individual Well-Being"
    assert html =~ "Well-Being summary"
  end

  test "?student_ids=<csv> scopes cohort to those students",
       %{conn: conn, admin: admin, students: [s1, s2, _s3]} do
    ids = "#{s1.id},#{s2.id}"

    {:ok, _lv, html} =
      conn |> log_in_user(admin) |> live(~p"/insights?student_ids=#{ids}")

    assert html =~ "Alice Adams"
    assert html =~ "Bob Brown"
    refute html =~ "Carol Chen"
  end

  test "?list_id=<uuid> scopes cohort to the list's students",
       %{conn: conn, admin: admin, students: [s1 | _]} do
    # Tag s1 so we can define a list that matches it
    tag = create_tag!(admin.school_memberships |> hd() |> Map.get(:school_id) |> then(&%{id: &1}))
    _ = tag
    # Simpler: create a list with a name filter matching "Alice"
    alias Intellispark.Students.CustomList
    school_id = s1.school_id
    admin_loaded = Ash.load!(admin, [school_memberships: [:school]], authorize?: false)

    {:ok, list} =
      Ash.create(
        CustomList,
        %{name: "Test-Insights-#{:erlang.unique_integer([:positive])}",
          filters: %{name_contains: "Alice"}},
        tenant: school_id,
        actor: admin_loaded,
        authorize?: false
      )

    {:ok, _lv, html} =
      conn |> log_in_user(admin_loaded) |> live(~p"/insights?list_id=#{list.id}")

    assert html =~ "Alice Adams"
    refute html =~ "Bob Brown"
  end

  test "sidebar click updates URL via push_patch + re-renders both panels",
       %{conn: conn, admin: admin, students: [s1 | _]} do
    {:ok, lv, _html} =
      conn |> log_in_user(admin) |> live(~p"/insights?student_ids=#{s1.id}")

    html =
      lv
      |> element("button[phx-value-dim='engagement']")
      |> render_click()

    assert html =~ "Individual Engagement"
    assert html =~ "Engagement summary"
  end

  test "student name link points at /students/:id",
       %{conn: conn, admin: admin, students: [s1 | _]} do
    {:ok, lv, _html} =
      conn |> log_in_user(admin) |> live(~p"/insights?student_ids=#{s1.id}")

    assert has_element?(lv, "a[href='/students/#{s1.id}']")
  end

  test "Cancel link navigates to return_to param",
       %{conn: conn, admin: admin, students: [s1 | _]} do
    {:ok, lv, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/insights?student_ids=#{s1.id}&return_to=/lists")

    assert has_element?(lv, "a[href='/lists']", "Cancel")
  end

  test "empty cohort renders 'No students in this cohort.' message",
       %{conn: conn, admin: admin} do
    {:ok, _lv, html} =
      conn |> log_in_user(admin) |> live(~p"/insights?student_ids=")

    assert html =~ "No students in this cohort."
  end
end
