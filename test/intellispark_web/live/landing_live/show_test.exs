defmodule IntellisparkWeb.LandingLive.ShowTest do
  use IntellisparkWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders identity + proof + CTAs", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/")

    assert html =~ "Intellispark"
    assert html =~ "Open the app as a demo admin"
    assert html =~ "Read the engineering journal"
    assert html =~ ~r/\d+ phases · \d+ tests · \d+ ADRs/
  end

  test "primary CTA link points at /demo", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/")
    assert lv |> element("a", "Open the app as a demo admin") |> render() =~ ~s|href="/demo"|
  end
end
