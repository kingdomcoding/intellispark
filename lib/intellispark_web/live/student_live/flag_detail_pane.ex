defmodule IntellisparkWeb.StudentLive.FlagDetailPane do
  @moduledoc """
  Tab-pane variant of `FlagDetailSheet` — same data, no fixed-position
  wrapper, no internal close button. Used by the Hub tab framework on
  `md:`+ viewports; the sheet still renders on `<md` for the bottom-sheet
  pattern.
  """

  use IntellisparkWeb, :live_component

  alias Intellispark.Flags
  alias Intellispark.Flags.Flag

  require Ash.Query

  @impl true
  def update(%{flag_id: flag_id, actor: actor, tenant: tenant} = assigns, socket) do
    case Flags.get_flag(flag_id, actor: actor, tenant: tenant) do
      {:ok, flag} ->
        flag =
          Ash.load!(
            flag,
            [:flag_type, :opened_by, :closed_by, assignments: [:user]],
            actor: actor,
            tenant: tenant,
            authorize?: false
          )

        {:ok,
         socket
         |> assign(assigns)
         |> assign(
           flag: flag,
           timeline: load_flag_timeline(flag, tenant),
           followup_form_open?: false,
           close_form_open?: false,
           close_note: "",
           followup_date: nil
         )}

      _ ->
        {:ok,
         socket
         |> assign(assigns)
         |> assign(flag: nil, timeline: [])}
    end
  end

  @impl true
  def render(%{flag: nil} = assigns) do
    ~H"""
    <div class="bg-white rounded-card shadow-card p-md">
      <p class="text-sm text-azure italic">Flag not found.</p>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="bg-white rounded-card shadow-card overflow-hidden">
      <header class="bg-white border-b border-abbey/10 px-md py-sm flex items-start gap-sm">
        <span
          class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full mt-0.5"
          style={"background: #{@flag.flag_type.color}; opacity: 0.25"}
        >
          <span class="hero-flag size-4 text-abbey"></span>
        </span>
        <div class="min-w-0">
          <p class="text-sm font-semibold text-abbey">{@flag.flag_type.name}</p>
          <p class="text-xs text-azure">
            Opened {relative_time(@flag.inserted_at)} by {@flag.opened_by.email}
          </p>
        </div>
      </header>

      <section class="px-md py-sm space-y-sm">
        <div class="flex items-center gap-xs">
          <span class={[
            "inline-flex items-center rounded-pill border px-2 py-0.5 text-xs font-medium",
            status_pill_classes(@flag.status)
          ]}>
            {status_label(@flag.status)}
          </span>
          <span :if={@flag.sensitive?} class="text-xs text-chocolate font-medium">
            Sensitive
          </span>
        </div>

        <p class="text-sm text-abbey whitespace-pre-line">{@flag.description}</p>

        <dl class="grid grid-cols-2 gap-x-sm gap-y-xs text-xs">
          <dt class="text-azure">Follow-up</dt>
          <dd class="text-abbey">
            {if @flag.followup_at, do: Date.to_string(@flag.followup_at), else: "—"}
          </dd>
          <dt class="text-azure">Auto-close</dt>
          <dd class="text-abbey">
            {if @flag.auto_close_at,
              do: Calendar.strftime(@flag.auto_close_at, "%b %-d, %Y"),
              else: "—"}
          </dd>
          <dt :if={@flag.resolution_note} class="text-azure">Resolution</dt>
          <dd :if={@flag.resolution_note} class="text-abbey">{@flag.resolution_note}</dd>
        </dl>

        <div>
          <h3 class="text-xs font-semibold text-abbey mb-xs">Assignees</h3>
          <ul class="space-y-0.5">
            <li :for={a <- active_assignments(@flag)} class="text-xs text-abbey">
              {a.user.email}
            </li>
            <li :if={active_assignments(@flag) == []} class="text-xs text-azure italic">
              No active assignees.
            </li>
          </ul>
        </div>

        <div class="flex flex-wrap gap-xs pt-sm border-t border-abbey/10">
          <.transition_button
            :if={@flag.status in [:open, :assigned] and not @close_form_open?}
            label="Move to Review"
            event="move_to_review"
            target={@myself}
          />
          <.transition_button
            :if={@flag.status in [:open, :assigned, :under_review] and not @close_form_open?}
            label="Set follow-up"
            event="open_followup_form"
            target={@myself}
          />
          <.transition_button
            :if={
              @flag.status in [:open, :assigned, :under_review, :pending_followup] and
                not @close_form_open?
            }
            label="Close"
            event="open_close_form"
            target={@myself}
          />
          <.transition_button
            :if={@flag.status == :closed and can_reopen?(@flag, @actor)}
            label="Reopen"
            event="reopen_flag"
            target={@myself}
          />
        </div>

        <div :if={@close_form_open?} class="pt-sm border-t border-abbey/10 space-y-xs">
          <form phx-submit="submit_close" phx-target={@myself} class="space-y-xs">
            <label class="text-xs font-medium text-abbey">Resolution note</label>
            <textarea
              name="resolution_note"
              required
              class="w-full rounded border border-abbey/20 p-xs text-sm"
            ><%= @close_note %></textarea>
            <div class="flex justify-end gap-xs">
              <.button type="button" variant={:ghost} phx-click="cancel_close" phx-target={@myself}>
                Cancel
              </.button>
              <.button type="submit" variant={:primary}>Close flag</.button>
            </div>
          </form>
        </div>

        <div :if={@followup_form_open?} class="pt-sm border-t border-abbey/10 space-y-xs">
          <form phx-submit="submit_followup" phx-target={@myself} class="space-y-xs">
            <label class="text-xs font-medium text-abbey">Follow up on</label>
            <input
              type="date"
              name="followup_at"
              required
              class="rounded border border-abbey/20 px-xs py-0.5 text-sm"
            />
            <div class="flex justify-end gap-xs">
              <.button type="button" variant={:ghost} phx-click="cancel_followup" phx-target={@myself}>
                Cancel
              </.button>
              <.button type="submit" variant={:primary}>Set</.button>
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
              <p class="text-[0.6875rem] text-azure">{relative_time(entry.version_inserted_at)}</p>
            </div>
          </li>
          <li :if={@timeline == []}>
            <p class="text-xs text-azure italic">No activity yet.</p>
          </li>
        </ol>
      </section>
    </div>
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
  def handle_event("move_to_review", _params, socket) do
    handle_transition(socket, fn flag, actor, tenant ->
      Flags.move_flag_to_review(flag, actor: actor, tenant: tenant)
    end)
  end

  def handle_event("open_followup_form", _params, socket) do
    {:noreply, assign(socket, followup_form_open?: true, close_form_open?: false)}
  end

  def handle_event("cancel_followup", _params, socket) do
    {:noreply, assign(socket, followup_form_open?: false)}
  end

  def handle_event("submit_followup", %{"followup_at" => raw}, socket) do
    case Date.from_iso8601(raw) do
      {:ok, date} ->
        handle_transition(socket, fn flag, actor, tenant ->
          Flags.set_flag_followup(flag, date, actor: actor, tenant: tenant)
        end)

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("open_close_form", _params, socket) do
    {:noreply, assign(socket, close_form_open?: true, followup_form_open?: false)}
  end

  def handle_event("cancel_close", _params, socket) do
    {:noreply, assign(socket, close_form_open?: false)}
  end

  def handle_event("submit_close", %{"resolution_note" => note}, socket)
      when is_binary(note) and note != "" do
    handle_transition(socket, fn flag, actor, tenant ->
      Flags.close_flag(flag, note, actor: actor, tenant: tenant)
    end)
  end

  def handle_event("submit_close", _, socket), do: {:noreply, socket}

  def handle_event("reopen_flag", _params, socket) do
    handle_transition(socket, fn flag, actor, tenant ->
      Flags.reopen_flag(flag, actor: actor, tenant: tenant)
    end)
  end

  defp handle_transition(socket, fun) do
    %{flag: flag, actor: actor, tenant: tenant} = socket.assigns

    case fun.(flag, actor, tenant) do
      {:ok, updated} ->
        send(self(), {IntellisparkWeb.StudentLive.FlagDetailSheet, :flag_changed})

        reloaded =
          Ash.load!(
            updated,
            [:flag_type, :opened_by, :closed_by, assignments: [:user]],
            actor: actor,
            tenant: tenant,
            authorize?: false
          )

        {:noreply,
         assign(socket,
           flag: reloaded,
           timeline: load_flag_timeline(reloaded, tenant),
           close_form_open?: false,
           followup_form_open?: false
         )}

      {:error, _err} ->
        {:noreply, socket}
    end
  end

  defp active_assignments(%{assignments: %Ash.NotLoaded{}}), do: []

  defp active_assignments(%{assignments: assignments}) do
    Enum.filter(assignments, &is_nil(&1.cleared_at))
  end

  defp active_assignments(_), do: []

  defp can_reopen?(flag, actor) do
    roles = actor |> Map.get(:school_memberships, []) |> List.wrap() |> Enum.map(& &1.role)
    actor.id == flag.opened_by_id or Enum.any?(roles, &(&1 == :admin))
  end

  defp load_flag_timeline(flag, tenant) do
    Flag.Version
    |> Ash.Query.filter(version_source_id == ^flag.id)
    |> Ash.Query.set_tenant(tenant)
    |> Ash.Query.sort([{:version_inserted_at, :desc}])
    |> Ash.read!(authorize?: false)
  end

  defp summarise(%{version_action_name: :create}), do: "Flag opened (draft)"
  defp summarise(%{version_action_name: :open_flag}), do: "Moved to open"
  defp summarise(%{version_action_name: :assign}), do: "Reassigned"
  defp summarise(%{version_action_name: :move_to_review}), do: "Moved to under review"
  defp summarise(%{version_action_name: :set_followup}), do: "Follow-up date set"

  defp summarise(%{version_action_name: :close_with_resolution}),
    do: "Closed with resolution"

  defp summarise(%{version_action_name: :auto_close}), do: "Auto-closed (no activity)"
  defp summarise(%{version_action_name: :reopen}), do: "Reopened"
  defp summarise(%{version_action_name: name}), do: "Updated (#{name})"

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

  defp status_pill_classes(:draft), do: "border-abbey/30 text-abbey bg-white"
  defp status_pill_classes(:open), do: "border-brand text-brand bg-white"
  defp status_pill_classes(:assigned), do: "border-brand-700 text-brand-700 bg-brand/5"

  defp status_pill_classes(:under_review),
    do: "border-chocolate text-chocolate bg-chocolate/5"

  defp status_pill_classes(:pending_followup),
    do: "border-status-followup-border text-status-followup-text bg-white"

  defp status_pill_classes(:closed),
    do: "border-status-resolved-border text-status-resolved-text bg-white"

  defp status_pill_classes(:reopened),
    do: "border-status-active-border text-status-active-text bg-white"

  defp status_label(:draft), do: "Draft"
  defp status_label(:open), do: "Open"
  defp status_label(:assigned), do: "Assigned"
  defp status_label(:under_review), do: "Under review"
  defp status_label(:pending_followup), do: "Pending follow-up"
  defp status_label(:closed), do: "Closed"
  defp status_label(:reopened), do: "Reopened"
end
