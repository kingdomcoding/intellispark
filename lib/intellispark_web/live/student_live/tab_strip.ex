defmodule IntellisparkWeb.StudentLive.TabStrip do
  @moduledoc """
  Tab strip rendered under the Student Hub header. Pinned `Profile` tab plus
  zero or more dynamically opened entity tabs (flag / support / about). On
  `<md` viewports the strip is hidden and a "Back to Profile" link is shown
  instead so the legacy side-sheet pattern keeps working.
  """

  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: IntellisparkWeb.Endpoint,
    router: IntellisparkWeb.Router,
    statics: IntellisparkWeb.static_paths()

  alias IntellisparkWeb.StudentLive.Tabs

  attr :student, :map, required: true
  attr :active_tab, :any, required: true
  attr :open_tabs, :list, required: true

  def tab_strip(assigns) do
    ~H"""
    <nav class="hidden md:flex items-center gap-md border-b border-abbey/10 px-sm">
      <.tab_link
        kind={:profile}
        active?={@active_tab == :profile}
        student={@student}
        label="Profile"
        icon="hero-user-circle-mini"
      />

      <.tab_link
        kind={:about}
        active?={@active_tab == :about}
        student={@student}
        label="About the Student"
        icon="hero-identification-mini"
      />

      <.tab_link
        :for={tab <- @open_tabs}
        kind={tab}
        active?={@active_tab == tab}
        student={@student}
        label={tab_label(tab)}
        icon={tab_icon(tab)}
        closeable?
      />
    </nav>

    <div :if={@active_tab != :profile} class="md:hidden px-sm py-xs">
      <.link
        patch={~p"/students/#{@student.id}?tab=profile"}
        class="text-sm text-brand inline-flex items-center gap-1"
      >
        <span class="hero-arrow-left-mini"></span> Back to Profile
      </.link>
    </div>
    """
  end

  attr :kind, :any, required: true
  attr :active?, :boolean, required: true
  attr :student, :map, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :closeable?, :boolean, default: false

  defp tab_link(assigns) do
    ~H"""
    <div class="relative flex items-center">
      <.link
        patch={~p"/students/#{@student.id}?tab=#{Tabs.to_param(@kind)}"}
        class={[
          "inline-flex items-center gap-1 px-sm py-sm text-sm border-b-2",
          @active? && "border-brand text-brand font-medium",
          not @active? && "border-transparent text-azure hover:text-abbey"
        ]}
      >
        <span class={"#{@icon} size-4"}></span>
        {@label}
      </.link>
      <button
        :if={@closeable?}
        type="button"
        phx-click="close_tab"
        phx-value-tab={Tabs.to_param(@kind)}
        aria-label={"Close #{@label}"}
        class="text-azure hover:text-chocolate ml-xs"
      >
        <span class="hero-x-mark-mini size-3.5"></span>
      </button>
    </div>
    """
  end

  defp tab_label(:about), do: "About the Student"
  defp tab_label({:flag, _id}), do: "Flag detail"
  defp tab_label({:support, _id}), do: "Support detail"

  defp tab_icon(:about), do: "hero-identification-mini"
  defp tab_icon({:flag, _}), do: "hero-flag-mini"
  defp tab_icon({:support, _}), do: "hero-life-buoy-mini"
end
