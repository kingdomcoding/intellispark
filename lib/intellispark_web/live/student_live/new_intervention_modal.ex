defmodule IntellisparkWeb.StudentLive.NewInterventionModal do
  @moduledoc false
  use IntellisparkWeb, :live_component

  require Ash.Query

  alias Intellispark.Support
  alias Intellispark.Support.InterventionLibraryItem

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:view, fn -> :list end)
     |> assign_new(:selected_item, fn -> nil end)
     |> assign_new(:error_message, fn -> nil end)
     |> load_items()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id={@id} on_cancel={JS.push("close_new_intervention_modal")} show>
        <:title>{title_for(@view)}</:title>

        <.list_view :if={@view == :list} myself={@myself} items={@items} />
        <.form_view
          :if={@view == :form}
          myself={@myself}
          item={@selected_item}
          staff={@staff}
        />

        <p :if={@error_message} class="text-xs text-chocolate pt-sm">{@error_message}</p>
      </.modal>
    </div>
    """
  end

  attr :myself, :any, required: true
  attr :items, :list, required: true

  defp list_view(assigns) do
    ~H"""
    <div class="space-y-sm">
      <p :if={@items == []} class="text-xs text-azure italic">
        No active interventions in the library. Ask an admin to seed the library via AshAdmin.
      </p>
      <ul :if={@items != []} class="divide-y divide-abbey/10">
        <li :for={item <- @items}>
          <button
            type="button"
            phx-click="pick_item"
            phx-value-id={item.id}
            phx-target={@myself}
            class="flex w-full items-center justify-between p-sm text-left hover:bg-whitesmoke"
          >
            <span>
              <span class="block text-sm text-abbey font-medium">{item.title}</span>
              <span class="block text-xs text-azure">
                {humanize_tier(item.mtss_tier)} · {item.default_duration_days} days
              </span>
            </span>
            <span class="text-xs text-brand">Pick</span>
          </button>
        </li>
      </ul>
    </div>
    """
  end

  attr :myself, :any, required: true
  attr :item, :map, required: true
  attr :staff, :list, required: true

  defp form_view(assigns) do
    ~H"""
    <form phx-submit="create_support" phx-target={@myself} class="space-y-sm">
      <div class="space-y-xs">
        <p class="text-xs text-azure">Intervention</p>
        <p class="text-sm font-medium text-abbey">{@item.title}</p>
        <p :if={@item.description} class="text-xs text-abbey">{@item.description}</p>
      </div>

      <label class="block">
        <span class="text-xs text-abbey">Provider (optional)</span>
        <select
          name="provider_staff_id"
          class="w-full rounded border border-abbey/20 p-xs text-sm"
        >
          <option value="">—</option>
          <option :for={s <- @staff} value={s.id}>{staff_label(s)}</option>
        </select>
      </label>

      <div class="flex justify-end gap-sm pt-md">
        <.button
          type="button"
          variant={:ghost}
          phx-click="go_back"
          phx-target={@myself}
        >
          ← Back
        </.button>
        <.button type="submit" variant={:primary}>Start intervention</.button>
      </div>
    </form>
    """
  end

  @impl true
  def handle_event("pick_item", %{"id" => id}, socket) do
    item = Enum.find(socket.assigns.items, &(&1.id == id))
    {:noreply, assign(socket, view: :form, selected_item: item, error_message: nil)}
  end

  def handle_event("go_back", _params, socket) do
    {:noreply, assign(socket, view: :list, selected_item: nil)}
  end

  def handle_event("create_support", params, socket) do
    %{actor: actor, student: student, selected_item: item} = socket.assigns
    provider_staff_id = nil_if_blank(params["provider_staff_id"])

    input = %{
      intervention_library_item_id: item.id,
      starts_at: Date.utc_today(),
      provider_staff_id: provider_staff_id
    }

    case Support.create_support_from_intervention(
           student.id,
           nil,
           input,
           actor: actor,
           tenant: student.school_id
         ) do
      {:ok, _support} ->
        send(self(), {__MODULE__, :support_added})
        {:noreply, socket}

      {:error, err} ->
        {:noreply, assign(socket, :error_message, format_error(err))}
    end
  end

  defp load_items(socket) do
    %{actor: actor, student: student} = socket.assigns

    items =
      InterventionLibraryItem
      |> Ash.Query.filter(active? == true)
      |> Ash.Query.sort(:title)
      |> Ash.read!(actor: actor, tenant: student.school_id)

    assign(socket, :items, items)
  end

  defp title_for(:list), do: "Choose an intervention"
  defp title_for(:form), do: "Start intervention"

  defp humanize_tier(:tier_1), do: "Tier 1"
  defp humanize_tier(:tier_2), do: "Tier 2"
  defp humanize_tier(:tier_3), do: "Tier 3"
  defp humanize_tier(_), do: "—"

  defp staff_label(%{first_name: f, last_name: l}) when is_binary(f) and is_binary(l),
    do: "#{f} #{l}"

  defp staff_label(%{email: email}), do: to_string(email)
  defp staff_label(_), do: "Staff"

  defp nil_if_blank(nil), do: nil
  defp nil_if_blank(""), do: nil
  defp nil_if_blank(s), do: s

  defp format_error(%Ash.Error.Forbidden{}), do: "You are not authorized to perform this action."

  defp format_error(%{errors: [first | _]}) do
    cond do
      is_binary(first) -> first
      is_exception(first) -> Exception.message(first)
      true -> to_string(first)
    end
  end

  defp format_error(_), do: "Something went wrong."
end
