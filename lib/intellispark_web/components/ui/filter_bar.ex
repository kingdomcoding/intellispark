defmodule IntellisparkWeb.UI.FilterBar do
  @moduledoc """
  /students filter bar — search + tag / status / grade / enrollment
  controls + Save view button. Each multi-control is a `<details>`
  disclosure (no JS hooks). Driven by the parent LV's filter_spec.
  """

  use Phoenix.Component

  attr :search, :string, default: ""
  attr :tag_ids, :list, default: []
  attr :status_ids, :list, default: []
  attr :grade_levels, :list, default: []
  attr :enrollment_statuses, :list, default: []
  attr :tags, :list, required: true
  attr :statuses, :list, required: true
  attr :on_search, :string, default: "search"
  attr :on_filter_change, :string, default: "filter_change"
  attr :on_clear, :string, default: "clear_filters"
  attr :on_save_view, :string, default: "open_save_view"
  attr :save_disabled?, :boolean, default: true
  attr :save_label, :string, default: "Save view as…"

  def filter_bar(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-sm">
      <form
        phx-change={@on_search}
        class="relative min-w-[14rem] max-w-[28rem]"
      >
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

      <form phx-change={@on_filter_change} class="flex flex-wrap items-center gap-sm">
        <.multi_select
          name="filter[tag_ids][]"
          label="Tags"
          selected={@tag_ids}
          options={Enum.map(@tags, &{&1.name, &1.id})}
        />

        <.multi_select
          name="filter[status_ids][]"
          label="Status"
          selected={@status_ids}
          options={Enum.map(@statuses, &{&1.name, &1.id})}
        />

        <.checkbox_group
          name="filter[grade_levels][]"
          label="Grade"
          selected={Enum.map(@grade_levels, &Integer.to_string/1)}
          options={Enum.map(6..12, &{"#{&1}", "#{&1}"})}
        />

        <.multi_select
          name="filter[enrollment_statuses][]"
          label="Enrollment"
          selected={Enum.map(@enrollment_statuses, &Atom.to_string/1)}
          options={[
            {"Active", "active"},
            {"Inactive", "inactive"},
            {"Graduated", "graduated"},
            {"Withdrawn", "withdrawn"}
          ]}
        />
      </form>

      <button
        :if={any_filter_active?(assigns)}
        type="button"
        phx-click={@on_clear}
        class="text-xs text-azure hover:underline"
      >
        Clear filters
      </button>

      <button
        type="button"
        phx-click={@on_save_view}
        disabled={@save_disabled?}
        class={[
          "ml-auto inline-flex items-center rounded-pill px-md py-2 text-sm font-medium",
          @save_disabled? && "border border-abbey/20 text-azure/50 cursor-not-allowed",
          not @save_disabled? && "bg-brand text-white hover:bg-brand-700"
        ]}
      >
        {@save_label}
      </button>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :selected, :list, default: []
  attr :options, :list, required: true

  defp multi_select(assigns) do
    ~H"""
    <details class="relative">
      <summary class="list-none cursor-pointer rounded-pill border border-abbey/20 bg-white px-md py-2 text-sm flex items-center gap-1">
        {@label}<span :if={@selected != []} class="text-xs text-brand">({length(@selected)})</span>
        <span class="hero-chevron-down-mini"></span>
      </summary>
      <div class="absolute z-10 mt-xs w-56 max-h-72 overflow-y-auto rounded-card bg-white shadow-elevated p-sm space-y-1">
        <label
          :for={{label, value} <- @options}
          class="flex items-center gap-2 text-sm cursor-pointer"
        >
          <input
            type="checkbox"
            name={@name}
            value={value}
            checked={"#{value}" in Enum.map(@selected, &"#{&1}")}
          />
          <span>{label}</span>
        </label>
        <p :if={@options == []} class="text-xs text-azure italic">No options.</p>
      </div>
    </details>
    """
  end

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :selected, :list, default: []
  attr :options, :list, required: true

  defp checkbox_group(assigns) do
    ~H"""
    <details class="relative">
      <summary class="list-none cursor-pointer rounded-pill border border-abbey/20 bg-white px-md py-2 text-sm flex items-center gap-1">
        {@label}<span :if={@selected != []} class="text-xs text-brand">({length(@selected)})</span>
        <span class="hero-chevron-down-mini"></span>
      </summary>
      <div class="absolute z-10 mt-xs w-48 rounded-card bg-white shadow-elevated p-sm">
        <div class="flex flex-wrap gap-2">
          <label
            :for={{label, value} <- @options}
            class="flex items-center gap-1 text-sm cursor-pointer"
          >
            <input
              type="checkbox"
              name={@name}
              value={value}
              checked={value in @selected}
            />
            <span>{label}</span>
          </label>
        </div>
      </div>
    </details>
    """
  end

  defp any_filter_active?(a) do
    a.tag_ids != [] or a.status_ids != [] or a.grade_levels != [] or
      a.enrollment_statuses != [] or (a.search || "") != ""
  end
end
