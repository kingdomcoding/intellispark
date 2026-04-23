defmodule IntellisparkWeb.DemoLive.Show do
  use IntellisparkWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Demo — Intellispark")
     |> assign(:signed_in?, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.public flash={@flash} signed_in?={@signed_in?}>
      <section class="mx-auto max-w-3xl px-md py-2xl">
        <h1 class="text-3xl font-bold text-abbey">Demo</h1>
        <p class="mt-sm text-azure">Persona picker lands in LP-2.</p>
      </section>
    </Layouts.public>
    """
  end
end
