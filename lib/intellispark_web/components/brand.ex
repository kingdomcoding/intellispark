defmodule IntellisparkWeb.BrandComponents do
  use Phoenix.Component
  use IntellisparkWeb, :verified_routes

  attr :class, :string, default: "h-8 w-8"

  def logo(assigns) do
    ~H"""
    <.link navigate={~p"/"} class="inline-flex items-center" aria-label="Intellispark home">
      <img src={~p"/images/logo-square.png"} alt="Intellispark" class={@class} />
    </.link>
    """
  end

  attr :class, :string, default: "h-10 w-auto"

  def wordmark(assigns) do
    ~H"""
    <img src={~p"/images/logo-horizontal.png"} alt="Intellispark" class={@class} />
    """
  end
end
