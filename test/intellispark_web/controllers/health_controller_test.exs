defmodule IntellisparkWeb.HealthControllerTest do
  use IntellisparkWeb.ConnCase, async: false

  setup do
    # The health controller runs SELECT 1 in its own Repo checkout. Under
    # sandbox the connection has to be explicitly shared with the controller
    # process, otherwise it can race with other tests' owners and fail.
    Ecto.Adapters.SQL.Sandbox.checkout(Intellispark.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Intellispark.Repo, {:shared, self()})
    :ok
  end

  test "GET /healthz returns ok when DB is reachable", %{conn: conn} do
    conn = get(conn, ~p"/healthz")
    assert response(conn, 200) =~ "ok"
  end
end
