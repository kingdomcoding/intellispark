defmodule IntellisparkWeb.Layouts do
  @moduledoc false
  use IntellisparkWeb, :html

  import IntellisparkWeb.BrandComponents

  embed_templates "layouts/*"

  attr :current_scope, :map, default: nil
  attr :current_user, :map, default: nil
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
          <.school_switcher current_user={@current_user} current_school={@current_school} />
          <a
            href="#"
            aria-label="Settings"
            title="Settings (coming soon)"
            class="text-azure hover:text-abbey cursor-default"
          >
            <span class="hero-cog-6-tooth"></span>
          </a>
          <.user_menu current_user={@current_user} />
        </div>
      </div>
      <div class="intellispark-accent-bar"></div>
    </header>

    <main class="min-h-[calc(100vh-4rem)] bg-whitesmoke">
      {render_slot(@inner_block)}
    </main>
    """
  end

  attr :current_user, :map, default: nil
  attr :current_school, :map, default: nil

  defp school_switcher(%{current_school: nil} = assigns), do: ~H""

  defp school_switcher(assigns) do
    memberships = (assigns.current_user && assigns.current_user.school_memberships) || []
    multi? = length(memberships) > 1
    assigns = assign(assigns, multi?: multi?, memberships: memberships)

    ~H"""
    <div class="relative">
      <button
        :if={@multi?}
        type="button"
        phx-click={JS.toggle(to: "#school-switcher-menu")}
        class="text-azure text-sm hover:text-abbey inline-flex items-center gap-1"
        aria-haspopup="true"
        aria-expanded="false"
      >
        {@current_school.name}
        <span class="hero-chevron-down-mini"></span>
      </button>
      <span :if={!@multi?} class="text-azure text-sm">{@current_school.name}</span>

      <div
        :if={@multi?}
        id="school-switcher-menu"
        class="hidden absolute right-0 mt-1 w-64 rounded-card bg-white shadow-elevated py-1 z-10"
        role="menu"
      >
        <form
          :for={membership <- @memberships}
          action={~p"/set-school"}
          method="post"
          class="w-full"
        >
          <input
            type="hidden"
            name="_csrf_token"
            value={Plug.CSRFProtection.get_csrf_token()}
          />
          <input type="hidden" name="school_id" value={membership.school_id} />
          <button
            type="submit"
            class={[
              "w-full text-left px-md py-xs text-sm hover:bg-whitesmoke",
              membership.school_id == @current_school.id && "bg-whitesmoke"
            ]}
            role="menuitem"
          >
            <span class="block">{membership_label(membership)}</span>
            <span class="block text-xs text-azure capitalize">{membership.role}</span>
          </button>
        </form>
      </div>
    </div>
    """
  end

  defp membership_label(%{school: %{name: name}}) when is_binary(name), do: name
  defp membership_label(%{school_id: id}), do: "School #{String.slice(to_string(id), 0..7)}"

  attr :current_user, :map, default: nil

  defp user_menu(%{current_user: nil} = assigns), do: ~H""

  defp user_menu(assigns) do
    ~H"""
    <div class="relative flex items-center">
      <button
        type="button"
        phx-click={JS.toggle(to: "#user-menu-panel")}
        aria-label="Your account"
        aria-haspopup="true"
        class="text-azure hover:text-abbey inline-flex items-center"
      >
        <span class="hero-user-circle"></span>
      </button>

      <div
        id="user-menu-panel"
        class="hidden absolute right-0 mt-1 w-64 rounded-card bg-white shadow-elevated py-1 z-10"
        role="menu"
        phx-click-away={JS.hide(to: "#user-menu-panel")}
      >
        <div class="px-md py-sm border-b border-abbey/10">
          <p class="text-sm font-medium text-abbey truncate">{display_name(@current_user)}</p>
          <p class="text-xs text-azure truncate">{to_string(@current_user.email)}</p>
        </div>

        <.link
          href={~p"/sign-out"}
          method="delete"
          role="menuitem"
          class="block px-md py-sm text-sm text-abbey hover:bg-whitesmoke"
        >
          Sign out
        </.link>
      </div>
    </div>
    """
  end

  defp display_name(%{first_name: f, last_name: l}) when is_binary(f) and is_binary(l),
    do: "#{f} #{l}"

  defp display_name(%{first_name: f}) when is_binary(f), do: f
  defp display_name(%{last_name: l}) when is_binary(l), do: l
  defp display_name(user), do: to_string(user.email)

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
