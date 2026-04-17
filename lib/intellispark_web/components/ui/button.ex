defmodule IntellisparkWeb.UI.Button do
  use Phoenix.Component

  attr :variant, :atom,
    default: :primary,
    values: [:primary, :secondary, :blue, :link, :ghost, :danger]

  attr :size, :atom, default: :md, values: [:sm, :md, :lg]
  attr :type, :string, default: "button"
  attr :navigate, :string, default: nil
  attr :patch, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :loading, :boolean, default: false
  attr :icon, :string, default: nil
  attr :icon_position, :atom, default: :left, values: [:left, :right]
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(form name value phx-click phx-disable-with)

  slot :inner_block, required: true

  def button(%{navigate: navigate} = assigns) when is_binary(navigate) do
    ~H"""
    <.link navigate={@navigate} class={[base_classes(@variant, @size), @class]} {@rest}>
      <.button_content icon={@icon} icon_position={@icon_position} loading={@loading}>
        {render_slot(@inner_block)}
      </.button_content>
    </.link>
    """
  end

  def button(%{patch: patch} = assigns) when is_binary(patch) do
    ~H"""
    <.link patch={@patch} class={[base_classes(@variant, @size), @class]} {@rest}>
      <.button_content icon={@icon} icon_position={@icon_position} loading={@loading}>
        {render_slot(@inner_block)}
      </.button_content>
    </.link>
    """
  end

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      disabled={@disabled or @loading}
      class={[base_classes(@variant, @size), @class]}
      {@rest}
    >
      <.button_content icon={@icon} icon_position={@icon_position} loading={@loading}>
        {render_slot(@inner_block)}
      </.button_content>
    </button>
    """
  end

  attr :loading, :boolean, required: true
  attr :icon, :string, default: nil
  attr :icon_position, :atom, default: :left
  slot :inner_block, required: true

  defp button_content(assigns) do
    ~H"""
    <span :if={@loading} class="hero-arrow-path animate-spin"></span>
    <span :if={@icon && @icon_position == :left && !@loading} class={@icon}></span>
    <span>{render_slot(@inner_block)}</span>
    <span :if={@icon && @icon_position == :right && !@loading} class={@icon}></span>
    """
  end

  defp base_classes(variant, size) do
    [
      "inline-flex items-center justify-center gap-2 rounded-pill font-medium",
      "transition-all duration-200",
      "focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:outline-none",
      "disabled:opacity-50 disabled:cursor-not-allowed",
      size_classes(size),
      variant_classes(variant)
    ]
  end

  defp size_classes(:sm), do: "px-4 py-1.5 text-sm"
  defp size_classes(:md), do: "px-6 py-3 text-base"
  defp size_classes(:lg), do: "px-8 py-4 text-lg"

  defp variant_classes(:primary) do
    "bg-chocolate text-white border border-chocolate hover:bg-chocolate-600 focus-visible:ring-chocolate"
  end

  defp variant_classes(:secondary) do
    "bg-transparent text-abbey border border-abbey hover:bg-abbey hover:text-white focus-visible:ring-abbey"
  end

  defp variant_classes(:blue) do
    "bg-brand text-white border border-brand hover:bg-brand-600 focus-visible:ring-brand"
  end

  defp variant_classes(:link) do
    "bg-transparent text-brand hover:text-brand-700 focus-visible:ring-brand !px-0 !py-0"
  end

  defp variant_classes(:ghost) do
    "bg-transparent text-abbey hover:bg-lightgrey focus-visible:ring-abbey"
  end

  defp variant_classes(:danger) do
    "bg-indicator-low-text text-white border border-indicator-low-text hover:opacity-90"
  end
end
