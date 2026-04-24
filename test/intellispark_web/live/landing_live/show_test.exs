defmodule IntellisparkWeb.LandingLive.ShowTest do
  use IntellisparkWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders identity + proof + primary CTA", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/")

    assert html =~ "Intellispark"
    assert html =~ ~r/Elixir.*Phoenix.*Ash/
    assert html =~ ~r/tagged releases/
    assert html =~ ~r/tests green/
    assert html =~ ~r/architecture decisions/
    assert html =~ "Sign in as a demo admin"
  end

  test "primary CTA posts to /demo/district_admin", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/")
    assert html =~ ~s|action="/demo/district_admin"|
    assert html =~ ~s|method="post"|
  end
end
