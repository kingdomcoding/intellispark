defmodule IntellisparkWeb.HighFiveViewLive do
  @moduledoc """
  Unauthenticated LiveView rendered at `/high-fives/:token`. Loads the
  HighFive by token, records the view after the socket connects, and
  renders a branded "you got a High 5!" page.
  """

  use IntellisparkWeb, :live_view

  alias Intellispark.Recognition

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Recognition.get_high_five_by_token(token, authorize?: false) do
      {:ok, high_five} ->
        hydrated =
          Ash.load!(high_five, [:student, :sent_by, :school, student: [:display_name]],
            tenant: high_five.school_id,
            authorize?: false
          )

        if connected?(socket) do
          send(self(), :record_view)
        end

        {:ok,
         socket
         |> assign(
           high_five: hydrated,
           not_found?: false,
           page_title: "A High 5 for #{hydrated.student.display_name}"
         )}

      _ ->
        {:ok,
         socket
         |> assign(high_five: nil, not_found?: true, page_title: "High 5 not found")}
    end
  end

  @impl true
  def handle_info(:record_view, %{assigns: %{high_five: hf}} = socket) when not is_nil(hf) do
    {:ok, _} =
      Recognition.record_high_five_view(hf, "unknown", nil,
        tenant: hf.school_id,
        authorize?: false
      )

    {:noreply, socket}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(%{not_found?: true} = assigns) do
    ~H"""
    <main class="min-h-screen bg-cream py-xl">
      <div class="container-sm bg-white rounded-card shadow-card p-lg text-center space-y-sm">
        <h1 class="text-display-sm text-abbey">Link expired</h1>
        <p class="text-sm text-azure">
          We couldn't find the High 5 you're looking for. The link may have expired or been sent in error.
        </p>
      </div>
    </main>
    """
  end

  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-cream py-xl">
      <div class="container-sm bg-white rounded-card shadow-elevated p-xl space-y-md">
        <div class="text-center space-y-xs">
          <span class="hero-hand-raised text-brand size-12 inline-block"></span>
          <h1 class="text-display-sm text-abbey">
            {@high_five.student.display_name} — you got a High 5!
          </h1>
          <p class="text-sm text-azure">
            From <strong>{@high_five.sent_by.email}</strong> at {@high_five.school.name}
          </p>
        </div>

        <article class="rounded-card p-md bg-status-resolved border border-status-resolved-border/40 space-y-xs">
          <h2 class="text-md font-semibold text-abbey">{@high_five.title}</h2>
          <p class="text-sm text-abbey whitespace-pre-line">{@high_five.body}</p>
        </article>

        <p class="text-xs text-azure text-center">
          Sent {relative_time(@high_five.sent_at)}
        </p>
      </div>
    </main>
    """
  end

  defp relative_time(%DateTime{} = ts) do
    diff = DateTime.diff(DateTime.utc_now(), ts, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      true -> Calendar.strftime(ts, "%b %-d, %Y")
    end
  end

  defp relative_time(_), do: ""
end
