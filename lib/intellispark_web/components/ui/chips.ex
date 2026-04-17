defmodule IntellisparkWeb.UI.Chips do
  use Phoenix.Component

  attr :level, :atom, required: true, values: [:low, :moderate, :high]
  attr :filled, :boolean, default: true
  attr :class, :string, default: nil

  def level_indicator(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center justify-center rounded-pill px-3 py-0.5 text-sm font-medium",
      level_classes(@level, @filled),
      @class
    ]}>
      {level_label(@level)}
    </span>
    """
  end

  defp level_classes(:low, true), do: "bg-indicator-low text-indicator-low-text"
  defp level_classes(:moderate, true), do: "bg-indicator-moderate text-indicator-moderate-text"
  defp level_classes(:high, true), do: "bg-indicator-high text-indicator-high-text"

  defp level_classes(:low, false) do
    "border border-indicator-low-border text-indicator-low-text bg-indicator-low/50"
  end

  defp level_classes(:moderate, false) do
    "border border-indicator-moderate-border text-indicator-moderate-text bg-indicator-moderate/50"
  end

  defp level_classes(:high, false) do
    "border border-indicator-high-border text-indicator-high-text bg-indicator-high/50"
  end

  defp level_label(:low), do: "Low"
  defp level_label(:moderate), do: "Moderate"
  defp level_label(:high), do: "High"

  attr :label, :string, required: true
  attr :removable, :boolean, default: false
  attr :on_remove, :string, default: nil
  attr :value, :string, default: nil

  def tag_chip(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1 rounded-md bg-lightgrey px-3 py-1 text-sm text-abbey">
      {@label}
      <button
        :if={@removable}
        type="button"
        phx-click={@on_remove}
        phx-value-id={@value}
        aria-label={"Remove #{@label}"}
        class="text-azure hover:text-abbey"
      >
        <span class="hero-x-mark-micro"></span>
      </button>
    </span>
    """
  end

  attr :label, :string, required: true
  attr :variant, :atom, default: :followup, values: [:followup, :resolved, :active, :custom]

  def status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-pill px-3 py-0.5 text-sm font-medium border bg-white",
      @variant == :followup && "border-status-followup-border text-status-followup-text",
      @variant == :resolved && "border-status-resolved-border text-status-resolved-text",
      @variant == :active && "border-status-active-border text-status-active-text",
      @variant == :custom && "border-abbey text-abbey"
    ]}>
      {@label}
    </span>
    """
  end

  attr :value, :integer, required: true
  attr :variant, :atom, default: :neutral, values: [:neutral, :high_fives, :flags, :supports]

  def count_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex h-8 w-8 items-center justify-center rounded-full border text-sm font-medium",
      @variant == :high_fives && "border-status-resolved-border text-status-resolved-text",
      @variant == :flags && "border-indicator-moderate-border text-indicator-moderate-text",
      @variant == :supports && "border-status-active-border text-status-active-text",
      @variant == :neutral && "border-azure text-azure"
    ]}>
      {@value}
    </span>
    """
  end
end
