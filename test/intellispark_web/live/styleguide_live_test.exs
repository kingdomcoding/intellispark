defmodule IntellisparkWeb.StyleguideLiveTest do
  use IntellisparkWeb.ConnCase
  import Phoenix.LiveViewTest

  test "styleguide renders the core design primitives", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/styleguide")

    for section <- [
          "Colors",
          "Typography",
          "Buttons",
          "Add Buttons",
          "Level Indicators",
          "Status Badges",
          "Tag Chips",
          "Count Badges",
          "Section Cards",
          "Avatars",
          "Modal",
          "Empty States"
        ] do
      assert html =~ section
    end
  end
end
