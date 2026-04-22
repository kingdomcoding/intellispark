defmodule IntellisparkWeb.InsightsLive do
  @moduledoc """
  Full-screen Insights view with 13-dimension sidebar, individual
  breakdown table, and donut chart summary. Cohort set via query
  params (`?student_ids=<csv>`, `?list_id=<uuid>`, or neither for
  school-wide). Dimension selection drives both panels via
  `push_patch`.
  """

  use IntellisparkWeb, :live_view

  alias Intellispark.Indicators
  alias Intellispark.Indicators.Dimension

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Insights", dimensions: Dimension.all())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    %{current_user: actor, current_school: school} = socket.assigns

    student_ids = resolve_student_ids(params, actor, school)
    dimension = resolve_dimension(params)

    summary = Indicators.summary_for(student_ids, dimension, school.id)
    individual = Indicators.individual_for(student_ids, dimension, school.id)

    {:noreply,
     socket
     |> assign(
       student_ids: student_ids,
       selected_dimension: dimension,
       summary: summary,
       individual: individual,
       list_id: params["list_id"],
       return_to: params["return_to"] || "/students",
       query_params: stripped_params(params)
     )}
  end

  @impl true
  def handle_event("select_dimension", %{"dim" => dim}, socket) do
    new_params = Map.put(socket.assigns.query_params, "dimension", dim)
    {:noreply, push_patch(socket, to: ~p"/insights?#{new_params}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_school={@current_school}>
      <section class="fixed inset-0 z-50 bg-abbey/40 overflow-auto">
        <div class="min-h-screen flex items-start justify-center p-md">
          <div class="bg-white rounded-card shadow-elevated w-full max-w-6xl my-xl">
            <header class="flex items-center justify-between p-md border-b border-abbey/10">
              <h1 class="text-display-xs text-abbey">Insights</h1>

              <div class="flex items-center gap-sm">
                <.link
                  href={csv_export_path(@query_params)}
                  class="text-sm text-brand hover:underline"
                >
                  Export CSV
                </.link>
                <.link
                  navigate={@return_to}
                  aria-label="Close insights"
                  class="text-azure hover:text-abbey"
                >
                  <span class="hero-x-mark"></span>
                </.link>
              </div>
            </header>

            <div class="grid grid-cols-12 gap-0 min-h-[32rem]">
              <.sidebar dimensions={@dimensions} selected={@selected_dimension} />

              <div
                :if={@student_ids == []}
                class="col-span-10 p-lg flex items-center justify-center text-azure"
              >
                No students in this cohort.
              </div>

              <.panels
                :if={@student_ids != []}
                individual={@individual}
                summary={@summary}
                dimension={@selected_dimension}
              />
            </div>

            <footer class="flex justify-end p-md border-t border-abbey/10">
              <.link navigate={@return_to} class="text-sm text-azure hover:text-abbey">
                Cancel
              </.link>
            </footer>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :dimensions, :list, required: true
  attr :selected, :atom, required: true

  defp sidebar(assigns) do
    ~H"""
    <nav
      class="col-span-2 border-r border-abbey/10 py-md"
      aria-label="Dimension selector"
    >
      <ul class="space-y-xs">
        <li :for={dim <- @dimensions}>
          <button
            type="button"
            phx-click="select_dimension"
            phx-value-dim={Atom.to_string(dim)}
            class={[
              "block w-full text-left px-md py-xs text-sm border-l-2",
              dim == @selected && "text-brand border-brand font-semibold",
              dim != @selected && "text-azure border-transparent hover:text-abbey"
            ]}
          >
            {Dimension.humanize(dim)}
          </button>
        </li>
      </ul>
    </nav>
    """
  end

  attr :individual, :list, required: true
  attr :summary, :map, required: true
  attr :dimension, :atom, required: true

  defp panels(assigns) do
    ~H"""
    <section class="col-span-6 p-md border-r border-abbey/10">
      <h2 class="text-md font-semibold text-abbey mb-md">
        Individual {Dimension.humanize(@dimension)}
      </h2>

      <div :if={@individual == []} class="text-sm text-azure italic">
        No students to display.
      </div>

      <table :if={@individual != []} class="w-full">
        <thead>
          <tr class="text-xs text-azure uppercase border-b border-abbey/10">
            <th class="text-left py-xs">Student</th>
            <th class="text-right py-xs">Reported level</th>
          </tr>
        </thead>
        <tbody>
          <tr
            :for={row <- @individual}
            class="border-b border-abbey/5 hover:bg-whitesmoke"
          >
            <td class="py-sm">
              <.link navigate={~p"/students/#{row.id}"} class="text-abbey hover:text-brand">
                {row.name}
              </.link>
            </td>
            <td class="py-sm text-right">
              <.level_indicator :if={row.level} level={row.level} />
              <span
                :if={is_nil(row.level)}
                class="inline-flex items-center rounded-pill border border-abbey/20 bg-whitesmoke px-2 py-0.5 text-[0.6875rem] text-azure"
              >
                — not measured
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </section>

    <aside class="col-span-4 p-md">
      <h2 class="text-md font-semibold text-abbey mb-md">
        {Dimension.humanize(@dimension)} summary
      </h2>

      <div class="flex items-start gap-md">
        <.donut summary={@summary} />
        <.legend summary={@summary} />
      </div>

      <p
        :if={@summary.unscored > 0}
        class="text-xs text-azure italic mt-sm"
      >
        Not yet measured: {@summary.unscored}
      </p>
    </aside>
    """
  end

  attr :summary, :map, required: true

  defp legend(assigns) do
    ~H"""
    <table class="flex-1 text-sm">
      <thead>
        <tr class="text-xs text-azure">
          <th class="text-left font-medium">Levels</th>
          <th class="text-right font-medium">Total students</th>
          <th class="text-right font-medium">% of group</th>
        </tr>
      </thead>
      <tbody>
        <.legend_row
          label="High"
          count={@summary.high}
          total={@summary.total}
          color="bg-indicator-high-text"
        />
        <.legend_row
          label="Moderate"
          count={@summary.moderate}
          total={@summary.total}
          color="bg-indicator-moderate-text"
        />
        <.legend_row
          label="Low"
          count={@summary.low}
          total={@summary.total}
          color="bg-indicator-low-text"
        />
      </tbody>
    </table>
    """
  end

  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :total, :integer, required: true
  attr :color, :string, required: true

  defp legend_row(assigns) do
    pct =
      if assigns.total == 0, do: 0, else: round(100 * assigns.count / assigns.total)

    assigns = assign(assigns, pct: pct)

    ~H"""
    <tr>
      <td class="py-0.5">
        <span class="inline-flex items-center gap-xs">
          <span class={["h-2 w-2 rounded-full", @color]}></span>
          {@label}
        </span>
      </td>
      <td class="text-right py-0.5">{@count}</td>
      <td class="text-right py-0.5">{@pct}%</td>
    </tr>
    """
  end

  defp resolve_student_ids(%{"student_ids" => csv}, _actor, _school) when is_binary(csv) do
    csv |> String.split(",") |> Enum.reject(&(&1 == ""))
  end

  defp resolve_student_ids(%{"list_id" => list_id}, actor, school) do
    case Intellispark.Students.run_custom_list(list_id, actor: actor, tenant: school.id) do
      {:ok, students} -> Enum.map(students, & &1.id)
      _ -> []
    end
  end

  defp resolve_student_ids(_params, _actor, school) do
    Intellispark.Students.Student
    |> Ash.Query.set_tenant(school.id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
  end

  defp resolve_dimension(%{"dimension" => str}) do
    case Dimension.from_string(str) do
      {:ok, dim} -> dim
      :error -> hd(Dimension.all())
    end
  end

  defp resolve_dimension(_), do: hd(Dimension.all())

  defp stripped_params(params) do
    params
    |> Map.take(~w(list_id student_ids dimension return_to))
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp csv_export_path(params) do
    "/insights/export.csv?" <> URI.encode_query(params)
  end
end
