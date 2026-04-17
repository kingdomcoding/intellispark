defmodule IntellisparkWeb.StyleguideLive do
  use IntellisparkWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Styleguide")}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="container-lg py-xl">
        <h1 class="text-display-md">Styleguide <span class="text-gradient-orange">(stub)</span></h1>
        <p class="mt-sm text-azure">Components populate in §10.</p>
      </div>
    </Layouts.app>
    """
  end
end
