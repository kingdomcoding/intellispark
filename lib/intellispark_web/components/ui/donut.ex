defmodule IntellisparkWeb.UI.Donut do
  @moduledoc """
  Pure-SVG donut chart for the Phase 9 Insights view. 160px with three
  colored arcs (high / moderate / low) over a gray base ring.
  Accessible via a `<title>` element + aria-label summarising the
  breakdown counts.
  """

  use Phoenix.Component

  @radius 60
  @stroke 20
  @diameter 160

  attr :summary, :map, required: true
  attr :class, :string, default: nil

  def donut(assigns) do
    segments = compute_segments(assigns.summary)
    label = donut_aria_label(assigns.summary)

    assigns =
      assigns
      |> assign(segments: segments, label: label)
      |> assign(diameter: @diameter, radius: @radius, stroke: @stroke)

    ~H"""
    <svg
      width={@diameter}
      height={@diameter}
      viewBox={"0 0 #{@diameter} #{@diameter}"}
      role="img"
      aria-label={@label}
      class={@class}
    >
      <title>{@label}</title>

      <circle
        cx={@diameter / 2}
        cy={@diameter / 2}
        r={@radius}
        fill="none"
        stroke="var(--color-abbey-10, #e5e5e5)"
        stroke-width={@stroke}
      />

      <path
        :for={seg <- @segments}
        d={seg.path}
        fill="none"
        stroke={seg.color}
        stroke-width={@stroke}
      />
    </svg>
    """
  end

  defp compute_segments(%{total: 0}), do: []

  defp compute_segments(%{low: l, moderate: m, high: h, total: t}) when t > 0 do
    order = [
      {"var(--color-indicator-high-text, #4a7f4a)", h},
      {"var(--color-indicator-moderate-text, #a8701f)", m},
      {"var(--color-indicator-low-text, #a13331)", l}
    ]

    {segments, _} =
      Enum.map_reduce(order, 0, fn {color, count}, offset ->
        if count == 0 do
          {nil, offset}
        else
          fraction = count / t
          seg = %{path: arc_path(offset, offset + fraction), color: color}
          {seg, offset + fraction}
        end
      end)

    Enum.reject(segments, &is_nil/1)
  end

  defp arc_path(start_fraction, end_fraction) do
    start_angle = start_fraction * 2 * :math.pi() - :math.pi() / 2
    end_angle = end_fraction * 2 * :math.pi() - :math.pi() / 2

    cx = @diameter / 2
    cy = @diameter / 2

    x1 = cx + @radius * :math.cos(start_angle)
    y1 = cy + @radius * :math.sin(start_angle)
    x2 = cx + @radius * :math.cos(end_angle)
    y2 = cy + @radius * :math.sin(end_angle)

    large_arc = if end_fraction - start_fraction > 0.5, do: 1, else: 0

    "M #{x1} #{y1} A #{@radius} #{@radius} 0 #{large_arc} 1 #{x2} #{y2}"
  end

  defp donut_aria_label(%{total: 0}), do: "No indicator data available"

  defp donut_aria_label(%{low: l, moderate: m, high: h, total: t}) do
    "Dimension breakdown: #{h} high, #{m} moderate, #{l} low of #{t} scored students"
  end
end
