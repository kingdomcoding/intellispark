defmodule IntellisparkWeb.PageControllerTest do
  use IntellisparkWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "Intellispark"
    assert body =~ "styleguide"
  end
end
