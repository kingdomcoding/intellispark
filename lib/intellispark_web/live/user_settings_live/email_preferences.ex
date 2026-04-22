defmodule IntellisparkWeb.UserSettingsLive.EmailPreferences do
  @moduledoc """
  /me/email-preferences — flat checkbox grid for opting in or out of each
  email kind. Auto-saves on `phx-change`.
  """

  use IntellisparkWeb, :live_view

  alias Intellispark.Accounts
  alias Intellispark.Accounts.EmailPreferences

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Email preferences")}
  end

  @impl true
  def handle_event("toggle", %{"kind" => kind}, socket) do
    user = socket.assigns.current_user
    enabled? = not EmailPreferences.opted_in?(user, kind)

    case Accounts.set_email_preference(user, kind, enabled?, actor: user) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(current_user: updated)
         |> put_flash(:info, flash_for(kind, enabled?))}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not update preference.")}
    end
  end

  defp flash_for(kind, true), do: "#{humanize(kind)}: on"
  defp flash_for(kind, false), do: "#{humanize(kind)}: off"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_school={@current_school}>
      <section class="container-md py-xl space-y-md">
        <h1 class="text-display-md text-brand">Email preferences</h1>
        <p class="text-sm text-azure">
          Choose which Intellispark emails you'd like to receive. Preferences apply across every school you have access to.
        </p>

        <div class="bg-white rounded-card shadow-card p-md space-y-sm">
          <.preference_row
            :for={kind <- EmailPreferences.valid_kinds()}
            kind={kind}
            label={humanize(kind)}
            description={describe(kind)}
            opted_in?={EmailPreferences.opted_in?(@current_user, kind)}
          />
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :kind, :string, required: true
  attr :label, :string, required: true
  attr :description, :string, required: true
  attr :opted_in?, :boolean, required: true

  defp preference_row(assigns) do
    ~H"""
    <label class="flex items-start gap-sm cursor-pointer p-xs hover:bg-whitesmoke rounded">
      <input
        type="checkbox"
        phx-click="toggle"
        phx-value-kind={@kind}
        checked={@opted_in?}
        class="mt-1"
      />
      <div>
        <p class="text-sm font-medium text-abbey">{@label}</p>
        <p class="text-xs text-azure">{@description}</p>
      </div>
    </label>
    """
  end

  defp humanize("high_five_received"), do: "High 5 received"
  defp humanize("high_five_resent"), do: "High 5 re-sent"
  defp humanize("flag_assigned"), do: "Flag assigned to me"
  defp humanize("flag_followup"), do: "Flag follow-up reminder"
  defp humanize("action_due"), do: "Action due reminder"
  defp humanize("weekly_digest"), do: "Weekly digest (Mondays)"

  defp describe("high_five_received"), do: "When a colleague sends a High 5 to a student."
  defp describe("high_five_resent"), do: "When a colleague re-sends an existing High 5."
  defp describe("flag_assigned"), do: "When a flag is assigned to you for a student."
  defp describe("flag_followup"), do: "Daily summary of flags awaiting your follow-up."
  defp describe("action_due"), do: "Daily summary of actions due to you today."

  defp describe("weekly_digest"),
    do: "Monday morning summary of last week's activity for students you support."
end
