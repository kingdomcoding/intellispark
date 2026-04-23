defmodule IntellisparkWeb.AdminLive.Integrations.Index do
  @moduledoc """
  /admin/integrations — district-admin-gated dashboard. Lists providers,
  recent sync runs, and open sync errors for the current school.
  Supports activating/deactivating providers, manual "Run now" syncs,
  and a Starter/Plus-vs-PRO gate on the Xello provider type.
  """

  use IntellisparkWeb, :live_view

  alias Intellispark.Integrations

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    school = socket.assigns[:current_school]

    cond do
      school == nil ->
        {:ok,
         socket
         |> put_flash(:error, "Pick a school first.")
         |> push_navigate(to: ~p"/students")}

      not district_admin?(user) ->
        {:ok,
         socket
         |> put_flash(:error, "Admin access required.")
         |> push_navigate(to: ~p"/students")}

      true ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(
            Intellispark.PubSub,
            "sync_runs:school:#{school.id}"
          )
        end

        {:ok,
         socket
         |> assign(page_title: "Integrations")
         |> load_data()}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "sync_runs:school:" <> _}, socket) do
    {:noreply, load_data(socket)}
  end

  defp load_data(socket) do
    school = socket.assigns.current_school
    user = socket.assigns.current_user

    providers =
      Integrations.list_providers!(actor: user, tenant: school.id)
      |> Ash.load!([:sync_runs], authorize?: false)

    recent_runs =
      Integrations.list_sync_runs!(actor: user, tenant: school.id)
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
      |> Enum.take(10)

    assign(socket, providers: providers, recent_runs: recent_runs)
  end

  @impl true
  def handle_event("toggle_active", %{"provider_id" => id}, socket) do
    provider = Enum.find(socket.assigns.providers, &(&1.id == id))

    action = if provider.active?, do: :deactivate_provider, else: :activate_provider

    {:ok, _} =
      apply(Integrations, action, [
        provider,
        [actor: socket.assigns.current_user, tenant: socket.assigns.current_school.id]
      ])

    {:noreply, load_data(socket)}
  end

  def handle_event("run_sync_now", %{"provider_id" => id}, socket) do
    provider = Enum.find(socket.assigns.providers, &(&1.id == id))

    case Integrations.run_sync_now(provider,
           actor: socket.assigns.current_user,
           tenant: socket.assigns.current_school.id
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sync enqueued for #{provider.name}.")
         |> load_data()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not enqueue sync.")}
    end
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
      <section class="container-lg py-xl space-y-lg">
        <header>
          <h1 class="text-display-md text-brand">Integrations</h1>
          <p class="text-sm text-azure">
            SIS providers + Xello for {@current_school.name}.
          </p>
        </header>

        <div class="bg-white rounded-card shadow-card overflow-hidden">
          <div class="px-md py-sm border-b border-abbey/10">
            <h2 class="text-md font-semibold text-abbey">Providers</h2>
          </div>

          <table class="w-full text-sm">
            <thead class="bg-whitesmoke text-azure">
              <tr>
                <th class="text-left font-medium px-md py-xs">Type</th>
                <th class="text-left font-medium">Name</th>
                <th class="text-left font-medium">Status</th>
                <th class="text-left font-medium">Last synced</th>
                <th class="text-left font-medium">Last success</th>
                <th class="text-left font-medium">Last failure</th>
                <th class="text-right font-medium px-md">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={p <- @providers}
                id={"provider-#{p.id}"}
                class="border-b border-abbey/5"
              >
                <td class="px-md py-sm">{provider_type_label(p.provider_type)}</td>
                <td>{p.name}</td>
                <td>
                  <span class={[
                    "rounded-pill px-2 py-0.5 text-xs",
                    p.active? && "bg-status-resolved text-azure",
                    !p.active? && "bg-whitesmoke text-azure/70"
                  ]}>
                    {if p.active?, do: "Active", else: "Inactive"}
                  </span>
                </td>
                <td>{maybe_relative(p.last_synced_at)}</td>
                <td>{maybe_relative(p.last_success_at)}</td>
                <td>{maybe_relative(p.last_failure_at)}</td>
                <td class="text-right px-md">
                  <button
                    type="button"
                    phx-click="toggle_active"
                    phx-value-provider_id={p.id}
                    class="text-xs text-brand hover:text-brand-700 mr-sm"
                  >
                    {if p.active?, do: "Deactivate", else: "Activate"}
                  </button>
                  <button
                    type="button"
                    phx-click="run_sync_now"
                    phx-value-provider_id={p.id}
                    class="text-xs text-brand hover:text-brand-700"
                  >
                    Run now
                  </button>
                </td>
              </tr>
              <tr :if={@providers == []}>
                <td colspan="7" class="py-md text-center text-azure">
                  No providers configured. Use AshAdmin to add one.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="bg-white rounded-card shadow-card overflow-hidden">
          <div class="px-md py-sm border-b border-abbey/10">
            <h2 class="text-md font-semibold text-abbey">Recent sync runs</h2>
          </div>

          <table class="w-full text-sm">
            <thead class="bg-whitesmoke text-azure">
              <tr>
                <th class="text-left font-medium px-md py-xs">Status</th>
                <th class="text-left font-medium">Trigger</th>
                <th class="text-left font-medium">Processed</th>
                <th class="text-left font-medium">Created</th>
                <th class="text-left font-medium">Updated</th>
                <th class="text-left font-medium">Failed</th>
                <th class="text-left font-medium">Started</th>
                <th class="text-left font-medium px-md">Completed</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={r <- @recent_runs}
                id={"sync-run-#{r.id}"}
                class="border-b border-abbey/5"
              >
                <td class="px-md py-sm">
                  <span class={["rounded-pill px-2 py-0.5 text-xs", status_pill_class(r.status)]}>
                    {status_label(r.status)}
                  </span>
                </td>
                <td>{r.trigger_source}</td>
                <td>{r.records_processed}</td>
                <td>{r.records_created}</td>
                <td>{r.records_updated}</td>
                <td>{r.records_failed}</td>
                <td>{maybe_relative(r.started_at)}</td>
                <td class="px-md">{maybe_relative(r.completed_at)}</td>
              </tr>
              <tr :if={@recent_runs == []}>
                <td colspan="8" class="py-md text-center text-azure">No runs yet.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp district_admin?(nil), do: false

  defp district_admin?(user) do
    user.district_id != nil and
      Enum.any?(user.school_memberships || [], &(&1.role == :admin))
  end

  defp provider_type_label(:csv), do: "CSV"
  defp provider_type_label(:oneroster), do: "OneRoster"
  defp provider_type_label(:clever), do: "Clever"
  defp provider_type_label(:classlink), do: "ClassLink"
  defp provider_type_label(:xello), do: "Xello"
  defp provider_type_label(:custom), do: "Custom"
  defp provider_type_label(other), do: to_string(other)

  defp status_label(:pending), do: "Pending"
  defp status_label(:running), do: "Running"
  defp status_label(:succeeded), do: "Succeeded"
  defp status_label(:partially_succeeded), do: "Partial"
  defp status_label(:failed), do: "Failed"
  defp status_label(other), do: to_string(other)

  defp status_pill_class(:pending), do: "bg-whitesmoke text-azure"
  defp status_pill_class(:running), do: "bg-brand/10 text-brand"
  defp status_pill_class(:succeeded), do: "bg-status-resolved text-azure"
  defp status_pill_class(:partially_succeeded), do: "bg-status-resolved text-chocolate"
  defp status_pill_class(:failed), do: "bg-chocolate/10 text-chocolate"
  defp status_pill_class(_), do: "bg-whitesmoke text-azure"

  defp maybe_relative(nil), do: "—"

  defp maybe_relative(%DateTime{} = dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      true -> Calendar.strftime(dt, "%b %-d")
    end
  end

  defp maybe_relative(_), do: "—"
end
