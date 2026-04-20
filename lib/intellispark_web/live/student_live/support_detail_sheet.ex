defmodule IntellisparkWeb.StudentLive.SupportDetailSheet do
  @moduledoc """
  Right-docked side-sheet for a selected Support. Shows title, status,
  provider, date range, state-conditional transition buttons, and a mini
  paper-trail timeline. Transitions route through the Support
  code-interface so PubSub broadcasts refresh the parent hub panel.
  """

  use IntellisparkWeb, :live_component

  alias Intellispark.Support
  alias Intellispark.Support.Support, as: SupportPlan

  require Ash.Query

  @impl true
  def update(%{support_id: support_id, actor: actor, tenant: tenant} = assigns, socket) do
    case Support.get_support(support_id, actor: actor, tenant: tenant) do
      {:ok, support} ->
        support =
          Ash.load!(support, [:provider_staff, :offered_by],
            actor: actor,
            tenant: tenant,
            authorize?: false
          )

        {:ok,
         socket
         |> assign(assigns)
         |> assign(
           support: support,
           timeline: load_support_timeline(support, tenant),
           decline_form_open?: false,
           decline_reason: ""
         )}

      _ ->
        {:ok, socket |> assign(assigns) |> assign(support: nil, timeline: [])}
    end
  end

  @impl true
  def render(%{support: nil} = assigns) do
    ~H"""
    <aside class="fixed inset-y-0 right-0 w-full max-w-[32rem] bg-white shadow-prominent z-40 p-md overflow-y-auto">
      <p class="text-sm text-azure italic">Support not found.</p>
      <.button variant={:ghost} phx-click="close_support_sheet">Close</.button>
    </aside>
    """
  end

  def render(assigns) do
    ~H"""
    <aside class="fixed inset-y-0 right-0 w-full max-w-[32rem] bg-white shadow-prominent z-40 overflow-y-auto">
      <header class="sticky top-0 bg-white border-b border-abbey/10 px-md py-sm flex items-start justify-between gap-sm">
        <div class="flex items-start gap-sm min-w-0">
          <span class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full mt-0.5 bg-brand/15">
            <span class="hero-heart size-4 text-brand"></span>
          </span>
          <div class="min-w-0">
            <p class="text-sm font-semibold text-abbey">{@support.title}</p>
            <p class="text-xs text-azure">
              Offered {relative_time(@support.inserted_at)} by {@support.offered_by.email}
            </p>
          </div>
        </div>
        <button
          type="button"
          phx-click="close_support_sheet"
          aria-label="Close"
          class="text-azure hover:text-abbey"
        >
          <span class="hero-x-mark size-5"></span>
        </button>
      </header>

      <section class="px-md py-sm space-y-sm">
        <div class="flex items-center gap-xs">
          <span class={[
            "inline-flex items-center rounded-pill border px-2 py-0.5 text-xs font-medium",
            pill_classes(@support.status)
          ]}>
            {pill_label(@support.status)}
          </span>
        </div>

        <p
          :if={@support.description}
          class="text-sm text-abbey whitespace-pre-line"
        >
          {@support.description}
        </p>

        <dl class="grid grid-cols-2 gap-x-sm gap-y-xs text-xs">
          <dt class="text-azure">Starts</dt>
          <dd class="text-abbey">
            {if @support.starts_at, do: Date.to_string(@support.starts_at), else: "—"}
          </dd>
          <dt class="text-azure">Ends</dt>
          <dd class="text-abbey">
            {if @support.ends_at, do: Date.to_string(@support.ends_at), else: "—"}
          </dd>
          <dt class="text-azure">Provider</dt>
          <dd class="text-abbey">
            {if @support.provider_staff, do: @support.provider_staff.email, else: "—"}
          </dd>
          <dt :if={@support.decline_reason} class="text-azure">Decline reason</dt>
          <dd :if={@support.decline_reason} class="text-abbey">
            {@support.decline_reason}
          </dd>
        </dl>

        <div class="flex flex-wrap gap-xs pt-sm border-t border-abbey/10">
          <.transition_button
            :if={@support.status == :offered and not @decline_form_open?}
            label="Accept"
            event="accept_support"
            target={@myself}
          />
          <.transition_button
            :if={@support.status == :offered and not @decline_form_open?}
            label="Decline"
            event="open_decline_form"
            target={@myself}
          />
          <.transition_button
            :if={@support.status == :in_progress}
            label="Mark complete"
            event="complete_support"
            target={@myself}
          />
        </div>

        <div
          :if={@decline_form_open?}
          class="pt-sm border-t border-abbey/10 space-y-xs"
        >
          <form phx-submit="submit_decline" phx-target={@myself} class="space-y-xs">
            <label class="text-xs font-medium text-abbey">Decline reason (optional)</label>
            <textarea
              name="reason"
              class="w-full rounded border border-abbey/20 p-xs text-sm"
            ><%= @decline_reason %></textarea>
            <div class="flex justify-end gap-xs">
              <.button
                type="button"
                variant={:ghost}
                phx-click="cancel_decline"
                phx-target={@myself}
              >
                Cancel
              </.button>
              <.button type="submit" variant={:primary}>Decline</.button>
            </div>
          </form>
        </div>
      </section>

      <section class="px-md py-sm border-t border-abbey/10">
        <h3 class="text-xs font-semibold text-abbey mb-sm">Activity</h3>
        <ol class="space-y-xs">
          <li :for={entry <- @timeline} class="flex gap-xs items-start">
            <span class="hero-arrow-right-circle size-3.5 text-azure mt-1"></span>
            <div class="flex-1">
              <p class="text-xs text-abbey">{summarise(entry)}</p>
              <p class="text-[0.6875rem] text-azure">
                {relative_time(entry.version_inserted_at)}
              </p>
            </div>
          </li>
          <li :if={@timeline == []}>
            <p class="text-xs text-azure italic">No activity yet.</p>
          </li>
        </ol>
      </section>
    </aside>
    """
  end

  attr :label, :string, required: true
  attr :event, :string, required: true
  attr :target, :any, required: true

  defp transition_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={@event}
      phx-target={@target}
      class="inline-flex items-center gap-1 rounded-pill border border-abbey/20 bg-white px-md py-1 text-xs font-medium text-brand hover:bg-whitesmoke"
    >
      {@label}
    </button>
    """
  end

  @impl true
  def handle_event("accept_support", _params, socket) do
    handle_transition(socket, &Support.accept_support/2, false)
  end

  def handle_event("complete_support", _params, socket) do
    handle_transition(socket, &Support.complete_support/2, true)
  end

  def handle_event("open_decline_form", _params, socket) do
    {:noreply, assign(socket, decline_form_open?: true)}
  end

  def handle_event("cancel_decline", _params, socket) do
    {:noreply, assign(socket, decline_form_open?: false)}
  end

  def handle_event("submit_decline", %{"reason" => reason}, socket) do
    %{support: support, actor: actor, tenant: tenant} = socket.assigns

    case Support.decline_support(support, %{reason: reason}, actor: actor, tenant: tenant) do
      {:ok, _updated} ->
        send(self(), {__MODULE__, :support_closed})
        {:noreply, socket}

      {:error, _err} ->
        {:noreply, socket}
    end
  end

  defp handle_transition(socket, fun, close_after?) do
    %{support: support, actor: actor, tenant: tenant} = socket.assigns

    case fun.(support, actor: actor, tenant: tenant) do
      {:ok, updated} ->
        message = if close_after?, do: :support_closed, else: :support_changed
        send(self(), {__MODULE__, message})

        reloaded =
          Ash.load!(updated, [:provider_staff, :offered_by],
            actor: actor,
            tenant: tenant,
            authorize?: false
          )

        {:noreply,
         assign(socket,
           support: reloaded,
           timeline: load_support_timeline(reloaded, tenant),
           decline_form_open?: false
         )}

      {:error, _err} ->
        {:noreply, socket}
    end
  end

  defp load_support_timeline(support, tenant) do
    SupportPlan.Version
    |> Ash.Query.filter(version_source_id == ^support.id)
    |> Ash.Query.set_tenant(tenant)
    |> Ash.Query.sort([{:version_inserted_at, :desc}])
    |> Ash.read!(authorize?: false)
  end

  defp summarise(%{version_action_name: :create}), do: "Support offered"
  defp summarise(%{version_action_name: :accept}), do: "Accepted — in progress"
  defp summarise(%{version_action_name: :decline}), do: "Declined"
  defp summarise(%{version_action_name: :complete}), do: "Completed"
  defp summarise(%{version_action_name: :update}), do: "Updated"
  defp summarise(%{version_action_name: name}), do: "Support #{name}"

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

  defp relative_time(%NaiveDateTime{} = ts) do
    ts |> DateTime.from_naive!("Etc/UTC") |> relative_time()
  end

  defp relative_time(_), do: ""

  defp pill_classes(:offered), do: "border-abbey/30 text-abbey bg-white"
  defp pill_classes(:in_progress), do: "border-brand text-brand bg-brand/5"

  defp pill_classes(:completed),
    do: "border-status-resolved-border text-status-resolved-text bg-white"

  defp pill_classes(:declined), do: "border-chocolate text-chocolate bg-chocolate/5"

  defp pill_label(:offered), do: "Offered"
  defp pill_label(:in_progress), do: "In progress"
  defp pill_label(:completed), do: "Completed"
  defp pill_label(:declined), do: "Declined"
end
