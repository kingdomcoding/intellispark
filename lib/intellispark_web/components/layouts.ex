defmodule IntellisparkWeb.Layouts do
  @moduledoc false
  use IntellisparkWeb, :html

  import IntellisparkWeb.BrandComponents

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :current_school, :map, default: nil
  attr :breadcrumb, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="bg-white">
      <div class="container-lg flex items-center justify-between py-xs">
        <div class="flex items-center gap-sm">
          <.logo />
          <nav :if={@breadcrumb} aria-label="Breadcrumb" class="text-sm">
            <.link
              navigate={@breadcrumb.path}
              class="text-brand hover:text-brand-700 flex items-center gap-1"
            >
              <span class="hero-arrow-left-mini"></span>
              {@breadcrumb.label}
            </.link>
          </nav>
        </div>

        <div class="flex items-center gap-sm">
          <span :if={@current_school} class="text-azure text-sm">
            {@current_school.name}
          </span>
          <a href="#" aria-label="Settings" class="text-azure hover:text-abbey">
            <span class="hero-cog-6-tooth"></span>
          </a>
          <a href="#" aria-label="Your profile" class="text-azure hover:text-abbey">
            <span class="hero-user-circle"></span>
          </a>
        </div>
      </div>
      <div class="intellispark-accent-bar"></div>
    </header>

    <main class="min-h-[calc(100vh-4rem)] bg-whitesmoke">
      <.flash_group flash={@flash} />
      {render_slot(@inner_block)}
    </main>
    """
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
