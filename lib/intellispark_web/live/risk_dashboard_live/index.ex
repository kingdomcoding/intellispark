defmodule IntellisparkWeb.RiskDashboardLive.Index do
  @moduledoc false
  use IntellisparkWeb, :live_view

  require Ash.Query

  alias Intellispark.Students.Student

  @skills ~w(confidence persistence organization getting_along resilience curiosity)a

  @impl true
  def mount(_params, _session, socket) do
    %{current_user: actor, current_school: school} = socket.assigns

    if on_pro?(school) do
      students = load_risk_ranked(actor, school, :all, :all)

      {:ok,
       socket
       |> assign(
         page_title: "Risk Dashboard",
         filter_band: :all,
         filter_skill: :all,
         students: students,
         skills: @skills
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "Risk Dashboard requires a PRO plan.")
       |> push_navigate(to: ~p"/students")}
    end
  end

  @impl true
  def handle_event("filter", params, socket) do
    %{current_user: actor, current_school: school} = socket.assigns

    filter_band = parse_band(params["band"])
    filter_skill = parse_skill(params["skill"])

    {:noreply,
     socket
     |> assign(
       filter_band: filter_band,
       filter_skill: filter_skill,
       students: load_risk_ranked(actor, school, filter_band, filter_skill)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_school={@current_school}
      onboarding_incomplete?={@onboarding_incomplete?}
    >
      <section class="container-lg py-xl space-y-md">
        <header class="flex items-center justify-between">
          <div>
            <h1 class="text-display-sm text-brand">Risk Dashboard</h1>
            <p class="text-sm text-azure">
              {length(@students)} students shown
            </p>
          </div>
          <.link navigate={~p"/students"} class="text-sm text-brand hover:underline">
            ← Back to All Students
          </.link>
        </header>

        <form
          phx-change="filter"
          class="bg-white rounded-card shadow-card p-md flex flex-wrap gap-md items-end"
        >
          <label class="block">
            <span class="text-xs text-azure">Risk band</span>
            <select name="band" class="mt-xs rounded border border-abbey/20 p-xs text-sm">
              <option value="all" selected={@filter_band == :all}>All</option>
              <option value="critical" selected={@filter_band == :critical}>Critical</option>
              <option value="high" selected={@filter_band == :high}>High</option>
              <option value="moderate" selected={@filter_band == :moderate}>Moderate</option>
              <option value="low" selected={@filter_band == :low}>Low</option>
            </select>
          </label>

          <label class="block">
            <span class="text-xs text-azure">Contributing skill</span>
            <select name="skill" class="mt-xs rounded border border-abbey/20 p-xs text-sm">
              <option value="all" selected={@filter_skill == :all}>All</option>
              <option :for={s <- @skills} value={Atom.to_string(s)} selected={@filter_skill == s}>
                {humanize_skill(s)}
              </option>
            </select>
          </label>
        </form>

        <div class="bg-white rounded-card shadow-card">
          <table class="w-full text-sm text-left text-abbey">
            <thead class="border-b border-abbey/10 text-xs uppercase tracking-wide text-azure">
              <tr>
                <th class="px-md py-sm">Student</th>
                <th class="px-md py-sm">Grade</th>
                <th class="px-md py-sm">Risk Band</th>
                <th class="px-md py-sm">Contributing Factors</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-abbey/10">
              <tr :if={@students == []}>
                <td colspan="4" class="px-md py-lg text-center text-azure italic">
                  No students match the current filter.
                </td>
              </tr>
              <tr
                :for={s <- @students}
                class="hover:bg-whitesmoke/40 cursor-pointer"
                phx-click={JS.navigate(~p"/students/#{s.id}?return_to=/students/risk")}
              >
                <td class="px-md py-sm">
                  <.link
                    navigate={~p"/students/#{s.id}?return_to=/students/risk"}
                    class="text-brand hover:text-brand-700"
                  >
                    {s.display_name || "#{s.first_name} #{s.last_name}"}
                  </.link>
                </td>
                <td class="px-md py-sm">{s.grade_level || "—"}</td>
                <td class="px-md py-sm">
                  <.risk_band_pill band={s.academic_risk_index} />
                </td>
                <td class="px-md py-sm">
                  {factors_join(s.contributing_factors)}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :band, :any, required: true

  defp risk_band_pill(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-pill px-sm py-0.5 text-xs font-medium",
      risk_pill_class(@band)
    ]}>
      {humanize_risk_band(@band)}
    </span>
    """
  end

  defp on_pro?(%{subscription: %{tier: :pro}}), do: true
  defp on_pro?(_), do: false

  defp parse_band(nil), do: :all
  defp parse_band("all"), do: :all
  defp parse_band(""), do: :all

  defp parse_band(str) when is_binary(str) do
    case str do
      "critical" -> :critical
      "high" -> :high
      "moderate" -> :moderate
      "low" -> :low
      _ -> :all
    end
  end

  defp parse_skill(nil), do: :all
  defp parse_skill("all"), do: :all
  defp parse_skill(""), do: :all

  defp parse_skill(str) when is_binary(str) do
    case str do
      "confidence" -> :confidence
      "persistence" -> :persistence
      "organization" -> :organization
      "getting_along" -> :getting_along
      "resilience" -> :resilience
      "curiosity" -> :curiosity
      _ -> :all
    end
  end

  defp load_risk_ranked(actor, school, band, skill) do
    Student
    |> Ash.Query.filter(enrollment_status == :active)
    |> Ash.Query.load([:display_name, :academic_risk_index, :contributing_factors])
    |> Ash.read!(actor: actor, tenant: school.id)
    |> Enum.filter(&band_matches?(&1.academic_risk_index, band))
    |> Enum.filter(&skill_matches?(&1.contributing_factors, skill))
    |> Enum.sort_by(&sort_key/1)
  end

  defp band_matches?(_, :all), do: true
  defp band_matches?(b, b), do: true
  defp band_matches?(_, _), do: false

  defp skill_matches?(_, :all), do: true
  defp skill_matches?(factors, skill) when is_list(factors), do: skill in factors
  defp skill_matches?(_, _), do: false

  defp sort_key(%{academic_risk_index: :critical}), do: 0
  defp sort_key(%{academic_risk_index: :high}), do: 1
  defp sort_key(%{academic_risk_index: :moderate}), do: 2
  defp sort_key(%{academic_risk_index: :low}), do: 3
  defp sort_key(_), do: 4

  defp humanize_skill(:confidence), do: "Confidence"
  defp humanize_skill(:persistence), do: "Persistence"
  defp humanize_skill(:organization), do: "Organization"
  defp humanize_skill(:getting_along), do: "Getting Along"
  defp humanize_skill(:resilience), do: "Resilience"
  defp humanize_skill(:curiosity), do: "Curiosity"
  defp humanize_skill(other) when is_atom(other), do: to_string(other)

  defp humanize_risk_band(:low), do: "Low"
  defp humanize_risk_band(:moderate), do: "Moderate"
  defp humanize_risk_band(:high), do: "High"
  defp humanize_risk_band(:critical), do: "Critical"
  defp humanize_risk_band(_), do: "Not assessed"

  defp risk_pill_class(:low), do: "bg-green-100 text-green-900"
  defp risk_pill_class(:moderate), do: "bg-yellow-100 text-yellow-900"
  defp risk_pill_class(:high), do: "bg-orange-100 text-orange-900"
  defp risk_pill_class(:critical), do: "bg-chocolate/10 text-chocolate"
  defp risk_pill_class(_), do: "bg-whitesmoke text-azure"

  defp factors_join(nil), do: "—"
  defp factors_join([]), do: "—"

  defp factors_join(factors) when is_list(factors) do
    factors |> Enum.map(&humanize_skill/1) |> Enum.join(", ")
  end

  defp factors_join(_), do: "—"
end
