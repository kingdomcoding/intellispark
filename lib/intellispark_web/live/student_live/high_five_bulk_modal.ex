defmodule IntellisparkWeb.StudentLive.HighFiveBulkModal do
  @moduledoc """
  Modal opened from the roster BulkToolbar. Takes the currently-selected
  student_ids + a template dropdown; submits through
  `Recognition.bulk_send_high_five/4`. Reports `{:bulk_success, n}` or
  `{:bulk_partial, ok, failed}` upstream.
  """

  use IntellisparkWeb, :live_component

  alias Intellispark.Recognition

  require Ash.Query

  @impl true
  def update(assigns, socket) do
    templates =
      Recognition.list_high_five_templates!(
        actor: assigns.actor,
        tenant: assigns.current_school.id,
        query:
          Ash.Query.filter(
            Intellispark.Recognition.HighFiveTemplate,
            active? == true
          )
      )

    {:ok,
     socket
     |> assign(assigns)
     |> assign(templates: templates, error_message: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id={@id} on_cancel={JS.push("close_bulk_modal")} show>
        <:title>
          Send a High 5 to {length(@selected_student_ids)} students
        </:title>

        <form phx-submit="bulk_send" phx-target={@myself} class="space-y-sm">
          <label class="text-sm font-medium text-abbey">Template</label>
          <select
            name="template_id"
            required
            class="w-full rounded border border-abbey/20 p-xs text-sm"
          >
            <option value="">— pick a template —</option>
            <option :for={t <- @templates} value={t.id}>
              {t.title} ({t.category})
            </option>
          </select>

          <p :if={@error_message} class="text-xs text-chocolate">{@error_message}</p>

          <div class="flex justify-end gap-sm pt-md">
            <.button
              type="button"
              variant={:ghost}
              phx-click={JS.push("close_bulk_modal")}
            >
              Cancel
            </.button>
            <.button type="submit" variant={:primary}>
              Send to {length(@selected_student_ids)}
            </.button>
          </div>
        </form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("bulk_send", %{"template_id" => tid}, socket) do
    %{actor: actor, current_school: school, selected_student_ids: ids} = socket.assigns

    case Recognition.bulk_send_high_five(ids, tid,
           actor: actor,
           tenant: school.id
         ) do
      {:ok, %Ash.BulkResult{records: records, errors: errs}}
      when is_list(records) and (is_nil(errs) or errs == []) ->
        send(self(), {__MODULE__, {:bulk_success, length(records)}})
        {:noreply, socket}

      {:ok, %Ash.BulkResult{records: records, errors: errs}} when is_list(errs) ->
        send(
          self(),
          {__MODULE__, {:bulk_partial, length(records || []), length(errs)}}
        )

        {:noreply, socket}

      _ ->
        {:noreply,
         assign(socket, error_message: "Bulk send failed. Check permissions.")}
    end
  end
end
