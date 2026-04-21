defmodule IntellisparkWeb.StudentLive.PreviousHighFivesDrawer do
  @moduledoc """
  Right-docked slide-over listing every High 5 ever sent to a student,
  reverse-chronologically, with per-row view-count footers.
  """

  use IntellisparkWeb, :live_component

  alias Intellispark.Recognition.HighFive

  require Ash.Query

  @impl true
  def update(%{student: student, actor: actor, tenant: tenant} = assigns, socket) do
    high_fives =
      HighFive
      |> Ash.Query.filter(student_id == ^student.id)
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.sort([{:sent_at, :desc}])
      |> Ash.Query.load([:view_audit_count])
      |> Ash.read!(actor: actor)
      |> Ash.load!([:sent_by], authorize?: false)

    {:ok, socket |> assign(assigns) |> assign(high_fives: high_fives)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <aside class="fixed inset-y-0 right-0 w-full max-w-[36rem] bg-white shadow-prominent z-40 overflow-y-auto">
      <header class="sticky top-0 bg-white border-b border-abbey/10 px-md py-sm flex items-center justify-between">
        <h2 class="text-sm font-semibold text-abbey">
          All High 5's for {@student.display_name}
        </h2>
        <button
          type="button"
          phx-click="close_previous_high_fives"
          aria-label="Close"
          class="text-azure hover:text-abbey"
        >
          <span class="hero-x-mark size-5"></span>
        </button>
      </header>

      <section class="px-md py-sm space-y-sm">
        <p :if={@high_fives == []} class="text-sm text-azure italic">None yet.</p>

        <article
          :for={h <- @high_fives}
          class="rounded-card p-sm bg-whitesmoke border border-abbey/10 space-y-0.5"
        >
          <div class="flex items-start justify-between gap-sm">
            <p class="text-sm font-semibold text-abbey">{h.title}</p>
            <span class="text-xs text-azure">{relative_time(h.sent_at)}</span>
          </div>
          <p class="text-sm text-abbey whitespace-pre-line">{h.body}</p>
          <p class="text-xs text-azure pt-xs">
            Sent by <strong>{h.sent_by.email}</strong> · viewed {h.view_audit_count} time<span :if={h.view_audit_count != 1}>s</span>
          </p>
        </article>
      </section>
    </aside>
    """
  end

  defp relative_time(%DateTime{} = ts) do
    diff = DateTime.diff(DateTime.utc_now(), ts, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86_400)}d ago"
      true -> Calendar.strftime(ts, "%b %-d, %Y")
    end
  end

  defp relative_time(_), do: ""
end
