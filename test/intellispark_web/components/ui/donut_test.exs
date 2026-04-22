defmodule IntellisparkWeb.UI.DonutTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  import IntellisparkWeb.UI.Donut

  test "empty summary renders base circle only, no path elements" do
    assigns = %{summary: %{high: 0, moderate: 0, low: 0, unscored: 0, total: 0}}

    html =
      rendered_to_string(~H"""
      <.donut summary={@summary} />
      """)

    assert html =~ ~s(<circle)
    refute html =~ ~s(<path)
    assert html =~ "No indicator data available"
  end

  test "full summary renders 3 path elements in high>moderate>low order" do
    assigns = %{summary: %{high: 4, moderate: 3, low: 3, unscored: 0, total: 10}}

    html =
      rendered_to_string(~H"""
      <.donut summary={@summary} />
      """)

    paths = Regex.scan(~r/<path[^>]*stroke="([^"]+)"/, html)
    strokes = Enum.map(paths, fn [_, color] -> color end)

    assert length(strokes) == 3
    [first, second, third] = strokes
    assert first =~ "indicator-high-text"
    assert second =~ "indicator-moderate-text"
    assert third =~ "indicator-low-text"
  end

  test "aria-label contains counts for all three levels + total" do
    assigns = %{summary: %{high: 4, moderate: 3, low: 3, unscored: 0, total: 10}}

    html =
      rendered_to_string(~H"""
      <.donut summary={@summary} />
      """)

    assert html =~ "4 high"
    assert html =~ "3 moderate"
    assert html =~ "3 low"
    assert html =~ "10 scored students"
  end
end
