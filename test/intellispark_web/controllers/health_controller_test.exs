defmodule IntellisparkWeb.HealthControllerTest do
  use IntellisparkWeb.ConnCase

  test "GET /healthz returns ok when DB is reachable", %{conn: conn} do
    conn = get(conn, ~p"/healthz")
    assert response(conn, 200) =~ "ok"
  end
end
