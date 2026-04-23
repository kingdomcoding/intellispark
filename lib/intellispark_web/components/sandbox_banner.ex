defmodule IntellisparkWeb.Components.SandboxBanner do
  use Phoenix.Component

  attr :demo_session, :map, default: nil

  def sandbox_banner(assigns) do
    ~H"""
    <div
      :if={@demo_session}
      id="sandbox-banner"
      phx-hook="SandboxBannerDismiss"
      class="bg-amber-50 border-b border-amber-200 px-md py-xs text-sm text-amber-900 flex items-center justify-between"
    >
      <span>
        <strong>Demo sandbox.</strong>
        Resets daily at 00:00 UTC. Please don't enter real student data.
        <em class="text-amber-700">Persona: {@demo_session.persona}</em>
      </span>
      <button id="sandbox-banner-dismiss" class="text-amber-700 hover:text-amber-900">
        <span class="hero-x-mark-mini size-4"></span>
      </button>
    </div>
    """
  end
end
