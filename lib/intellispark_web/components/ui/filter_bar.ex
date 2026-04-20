defmodule IntellisparkWeb.UI.FilterBar do
  use Phoenix.Component

  attr :search, :string, default: ""
  attr :on_search, :string, default: "search"
  attr :on_toggle_filters, :string, default: "toggle_filters"

  def filter_bar(assigns) do
    ~H"""
    <div class="flex items-center gap-sm">
      <button
        type="button"
        phx-click={@on_toggle_filters}
        class="inline-flex items-center gap-1 rounded-pill border border-abbey/20 bg-white px-md py-xs text-sm font-medium text-brand hover:bg-whitesmoke"
      >
        <span class="hero-funnel-mini"></span> Filters
      </button>

      <form phx-change={@on_search} class="relative flex-1 max-w-[28rem]">
        <span class="hero-magnifying-glass-mini absolute left-3 top-1/2 -translate-y-1/2 text-azure">
        </span>
        <input
          type="text"
          name="q"
          value={@search}
          placeholder="Search student by name"
          phx-debounce="300"
          class="w-full rounded-pill border border-abbey/20 bg-white pl-10 pr-4 py-2 text-sm text-abbey focus:outline-none focus:ring-2 focus:ring-chocolate focus:border-transparent"
        />
      </form>
    </div>
    """
  end
end
