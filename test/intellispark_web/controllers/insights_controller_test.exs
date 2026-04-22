defmodule IntellisparkWeb.InsightsControllerTest do
  use IntellisparkWeb.ConnCase, async: false

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
      Indicators.upsert_indicator_score(s3.id, :belonging, :high, 4.5, 2, tenant: world.school.id)

    Map.merge(
      %{conn: Phoenix.ConnTest.build_conn(), students: [s1, s2, s3]},
      world
    )
  end

  test "export returns 200 + CSV content-type + attachment filename",
       %{conn: conn, admin: admin, students: students} do
    ids = students |> Enum.map(& &1.id) |> Enum.join(",")

    conn =
      conn
      |> log_in_user(admin)
      |> get(~p"/insights/export.csv?dimension=belonging&student_ids=#{ids}")

    assert conn.status == 200

    [content_type | _] = Plug.Conn.get_resp_header(conn, "content-type")
    assert content_type =~ "text/csv"

    [disposition | _] = Plug.Conn.get_resp_header(conn, "content-disposition")
    assert disposition =~ ~r/insights-belonging-\d{4}-\d{2}-\d{2}\.csv/
  end

  test "CSV body has correct headers + one row per student",
       %{conn: conn, admin: admin, students: students} do
    ids = students |> Enum.map(& &1.id) |> Enum.join(",")

    conn =
      conn
      |> log_in_user(admin)
      |> get(~p"/insights/export.csv?dimension=belonging&student_ids=#{ids}")

    parsed = NimbleCSV.RFC4180.parse_string(conn.resp_body, skip_headers: false)
    [header | rows] = parsed

    assert header == ["Student", "Dimension", "Level"]
    assert length(rows) == 3

    names = Enum.map(rows, fn [name, _, _] -> name end)
    assert "Alice Adams" in names
    assert "Bob Brown" in names
    assert "Carol Chen" in names

    levels = rows |> Enum.map(fn [_, _, level] -> level end) |> Enum.sort()
    assert levels == ["high", "low", "moderate"]
  end

  test "empty cohort produces header-only CSV",
       %{conn: conn, admin: admin} do
    conn =
      conn
      |> log_in_user(admin)
      |> get(~p"/insights/export.csv?dimension=belonging&student_ids=")

    parsed = NimbleCSV.RFC4180.parse_string(conn.resp_body, skip_headers: false)
    assert parsed == [["Student", "Dimension", "Level"]]
  end
end
