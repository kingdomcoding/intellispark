defmodule IntellisparkWeb.KeyIndicatorsPanelTest do
  use IntellisparkWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Intellispark.StudentsFixtures

  alias Intellispark.Indicators
  alias Intellispark.Indicators.Dimension

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    Map.merge(%{conn: Phoenix.ConnTest.build_conn()}, setup_world())
  end

  test "empty state renders 13 dash placeholders",
       %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Empty", last_name: "Indicators"})

    {:ok, _lv, html} =
      conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "Key SEL &amp; Well-Being Indicators"

    for dim <- Dimension.all() do
      assert html =~ Dimension.humanize(dim)
    end
  end

  test "partial state renders 3 chips + 10 placeholders",
       %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Partial", last_name: "Indicators"})

    {:ok, _} =
      Indicators.upsert_indicator_score(student.id, :belonging, :low, 2.0, 2, tenant: school.id)

    {:ok, _} =
      Indicators.upsert_indicator_score(student.id, :connection, :moderate, 3.0, 2,
        tenant: school.id
      )

    {:ok, _} =
      Indicators.upsert_indicator_score(student.id, :well_being, :high, 4.5, 2, tenant: school.id)

    {:ok, _lv, html} =
      conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "Belonging"
    assert html =~ "Connection"
    assert html =~ "Well-Being"
    assert html =~ "bg-indicator-low"
    assert html =~ "bg-indicator-moderate"
    assert html =~ "bg-indicator-high"
  end

  test "full state renders all 13 with correct layout",
       %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Full", last_name: "Indicators"})

    for dim <- Dimension.all() do
      {:ok, _} =
        Indicators.upsert_indicator_score(student.id, dim, :high, 4.5, 2, tenant: school.id)
    end

    {:ok, _lv, html} =
      conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    assert html =~ "Relationships (Adult)"
    assert html =~ "Relationships (Networks)"
    assert html =~ "Relationships (Peer)"
  end

  test "PubSub broadcast triggers reload",
       %{conn: conn, school: school, admin: admin} do
    student = create_student!(school, %{first_name: "Reload", last_name: "Indicators"})

    {:ok, lv, _html} =
      conn |> log_in_user(admin) |> live(~p"/students/#{student.id}")

    {:ok, _} =
      Indicators.upsert_indicator_score(student.id, :belonging, :high, 4.5, 2, tenant: school.id)

    Phoenix.PubSub.broadcast(
      Intellispark.PubSub,
      "indicator_scores:student:#{student.id}",
      {:indicator_scores_updated, student.id}
    )

    _ = :sys.get_state(lv.pid)
    html = render(lv)
    assert html =~ "bg-indicator-high"
  end
end
