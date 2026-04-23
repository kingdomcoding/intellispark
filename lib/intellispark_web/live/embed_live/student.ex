defmodule IntellisparkWeb.EmbedLive.Student do
  @moduledoc """
  Public, unauthenticated student-embed view at
  `/embed/student/:embed_token`. Consumed by partner iframes (Xello).
  Renders an SEL & Well-Being indicator grid + a minimal flag table.
  Revoked tokens render a 410-style notice; expired + unknown tokens
  render safe fallbacks.
  """

  use IntellisparkWeb, :live_view

  require Ash.Query

  alias Intellispark.Flags.Flag
  alias Intellispark.Indicators.Dimension
  alias Intellispark.Indicators.IndicatorScore
  alias Intellispark.Integrations
  alias Intellispark.Students.Student

  @impl true
  def mount(%{"embed_token" => token}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Student embed")
     |> load(token)}
  end

  defp load(socket, token) do
    case Integrations.get_embed_token(token) do
      {:ok, embed_token} -> hydrate(socket, embed_token)
      _ -> assign(socket, state: :not_found)
    end
  end

  defp hydrate(socket, %{revoked_at: revoked}) when not is_nil(revoked),
    do: assign(socket, state: :revoked)

  defp hydrate(socket, %{expires_at: exp} = embed_token) do
    if exp && DateTime.compare(exp, DateTime.utc_now()) != :gt do
      assign(socket, state: :expired)
    else
      assign(socket,
        state: :ok,
        student: load_student(embed_token),
        indicators: load_indicators(embed_token),
        flags: load_flags(embed_token)
      )
    end
  end

  defp load_student(embed_token) do
    Ash.get!(Student, embed_token.student_id,
      tenant: embed_token.school_id,
      authorize?: false
    )
  end

  defp load_indicators(embed_token) do
    IndicatorScore
    |> Ash.Query.filter(student_id == ^embed_token.student_id)
    |> Ash.Query.set_tenant(embed_token.school_id)
    |> Ash.read!(authorize?: false)
  end

  defp load_flags(embed_token) do
    Flag
    |> Ash.Query.filter(student_id == ^embed_token.student_id)
    |> Ash.Query.load([:flag_type, :opened_by])
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(20)
    |> Ash.Query.set_tenant(embed_token.school_id)
    |> Ash.read!(authorize?: false)
  end

  @impl true
  def render(%{state: :revoked} = assigns) do
    ~H"""
    <Layouts.embed>
      <div class="p-lg text-center text-sm text-abbey">This embed has been revoked.</div>
    </Layouts.embed>
    """
  end

  def render(%{state: :expired} = assigns) do
    ~H"""
    <Layouts.embed>
      <div class="p-lg text-center text-sm text-abbey">This embed has expired.</div>
    </Layouts.embed>
    """
  end

  def render(%{state: :not_found} = assigns) do
    ~H"""
    <Layouts.embed>
      <div class="p-lg text-center text-sm text-abbey">Embed not found.</div>
    </Layouts.embed>
    """
  end

  def render(%{state: :ok} = assigns) do
    ~H"""
    <Layouts.embed>
      <div class="bg-white p-md space-y-md">
        <section>
          <h2 class="text-lg font-semibold text-abbey mb-sm">SEL &amp; Well-Being Indicators</h2>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-md">
            <.indicator_column band={:high} indicators={@indicators} />
            <.indicator_column band={:moderate} indicators={@indicators} />
            <.indicator_column band={:low} indicators={@indicators} />
          </div>
        </section>

        <section>
          <h3 class="text-md font-semibold text-abbey mb-sm">Flags</h3>
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-azure border-b border-abbey/10">
                <th class="py-xs font-medium">Flag</th>
                <th class="font-medium">Opened by</th>
                <th class="font-medium">Date Opened</th>
                <th class="font-medium">Status</th>
                <th class="font-medium">Assigned</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={flag <- @flags}
                class="border-b border-abbey/5"
                id={"embed-flag-#{flag.id}"}
              >
                <td class="py-xs">{flag_type_name(flag)}</td>
                <td>{opened_by_display(flag)}</td>
                <td>{format_date(flag.inserted_at)}</td>
                <td>{flag_status_label(flag.status)}</td>
                <td>{if has_assignments?(flag), do: "Yes", else: "No"}</td>
              </tr>
              <tr :if={@flags == []}>
                <td colspan="5" class="py-sm text-center text-azure">No flags recorded.</td>
              </tr>
            </tbody>
          </table>
        </section>
      </div>
    </Layouts.embed>
    """
  end

  attr :band, :atom, required: true
  attr :indicators, :list, required: true

  defp indicator_column(assigns) do
    ~H"""
    <div class="rounded-card border border-abbey/10 p-md">
      <h4 class={["text-sm font-semibold mb-sm", band_color(@band)]}>{band_label(@band)}</h4>
      <ul class="space-y-1 text-sm">
        <li :for={ind <- filter_band(@indicators, @band)}>{Dimension.humanize(ind.dimension)}</li>
        <li :if={filter_band(@indicators, @band) == []} class="text-azure text-xs italic">
          No items
        </li>
      </ul>
    </div>
    """
  end

  defp filter_band(indicators, band), do: Enum.filter(indicators, &(&1.level == band))

  defp band_label(:high), do: "High"
  defp band_label(:moderate), do: "Moderate"
  defp band_label(:low), do: "Low"

  defp band_color(:high), do: "text-[#3AAE5F]"
  defp band_color(:moderate), do: "text-[#E59F42]"
  defp band_color(:low), do: "text-[#D94A4A]"

  defp flag_type_name(%{flag_type: %{name: name}}) when is_binary(name), do: name
  defp flag_type_name(_), do: "—"

  defp opened_by_display(%{opened_by: %{first_name: f, last_name: l}})
       when is_binary(f) and is_binary(l),
       do: "#{f} #{l}"

  defp opened_by_display(%{opened_by: %{email: email}}) when is_binary(email), do: email
  defp opened_by_display(_), do: "—"

  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %-d, %Y")
  defp format_date(_), do: ""

  defp flag_status_label(:open), do: "Needs resolution"
  defp flag_status_label(:assigned), do: "Assigned"
  defp flag_status_label(:under_review), do: "Under review"
  defp flag_status_label(:pending_followup), do: "Pending follow-up"
  defp flag_status_label(:closed), do: "Closed"
  defp flag_status_label(:reopened), do: "Reopened"
  defp flag_status_label(other), do: other |> to_string() |> String.replace("_", " ")

  defp has_assignments?(%{assignee_count: n}) when is_integer(n) and n > 0, do: true
  defp has_assignments?(_), do: false
end
