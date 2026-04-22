defmodule IntellisparkWeb.UI.BulkToolbar do
  @moduledoc false

  use IntellisparkWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="fixed bottom-md left-1/2 -translate-x-1/2 z-40 bg-white rounded-pill shadow-elevated px-md py-sm flex items-center gap-md text-abbey"
    >
      <button
        type="button"
        phx-click="clear_selection"
        class="hover:text-navy"
        aria-label="Clear selection"
        title="Clear selection"
      >
        <span class="hero-x-mark"></span>
      </button>

      <span class="text-sm font-medium">{@count} selected</span>

      <div class="h-4 w-px bg-abbey/20"></div>

      <.bulk_icon
        action="insights"
        icon="hero-chart-bar"
        label="Insights"
        enabled?={true}
      />
      <.bulk_icon
        action="forms"
        icon="hero-clipboard-document"
        label="Assign Forms & Surveys"
        enabled?={true}
      />
      <.bulk_icon
        action="supports"
        icon="hero-check-circle"
        label="Assign Supports"
        enabled?={false}
        coming_in="Phase 5"
      />
      <.bulk_icon
        action="high_fives"
        icon="hero-hand-raised"
        label="Send High 5"
        enabled?={true}
      />
      <.bulk_icon action="tag" icon="hero-tag" label="Apply tag" enabled?={true} />
      <.bulk_icon
        action="team"
        icon="hero-user-plus"
        label="Assign team members"
        enabled?={true}
      />
      <.bulk_icon
        action="settings"
        icon="hero-cog-6-tooth"
        label="Bulk settings"
        enabled?={true}
      />
    </div>
    """
  end

  attr :action, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :enabled?, :boolean, required: true
  attr :coming_in, :string, default: nil

  defp bulk_icon(assigns) do
    ~H"""
    <div class="relative group">
      <button
        type="button"
        phx-click={@enabled? && "open_bulk_modal"}
        phx-value-action={@action}
        disabled={not @enabled?}
        class={[
          "p-1 rounded hover:bg-whitesmoke",
          @enabled? && "text-abbey hover:text-brand",
          not @enabled? && "text-abbey/30 cursor-not-allowed"
        ]}
        aria-label={@label}
      >
        <span class={"#{@icon} size-5"}></span>
      </button>
      <span class="absolute -top-8 left-1/2 -translate-x-1/2 bg-abbey text-white text-xs rounded px-2 py-1 whitespace-nowrap hidden group-hover:block pointer-events-none">
        {@label}{if @coming_in, do: " — #{@coming_in}", else: ""}
      </span>
    </div>
    """
  end
end
