defmodule IntellisparkWeb.StudentLive.SurveyBulkModal do
  @moduledoc """
  Bulk-assign a survey to the currently-selected student_ids on the
  /students roster. Two submit modes match the screenshot wording:
  "Assign even if previously completed" (`:assign_regardless`) and
  "Assign only if never assigned" (`:skip_if_previously_assigned`).
  """

  use IntellisparkWeb, :live_component

  alias Intellispark.Assessments

  require Ash.Query

  @impl true
  def update(assigns, socket) do
    templates =
      Assessments.list_survey_templates!(
        actor: assigns.actor,
        tenant: assigns.current_school.id,
        query:
          Ash.Query.filter(
            Intellispark.Assessments.SurveyTemplate,
            published? == true
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
          Assign a survey to {length(@selected_student_ids)} students
        </:title>

        <form phx-submit="bulk_assign" phx-target={@myself} class="space-y-sm">
          <label class="text-sm font-medium text-abbey">Select form to assign</label>
          <select
            name="template_id"
            required
            class="w-full rounded border border-abbey/20 p-xs text-sm"
          >
            <option value="">Select form</option>
            <option :for={t <- @templates} value={t.id}>{t.name}</option>
          </select>

          <p :if={@error_message} class="text-xs text-chocolate">{@error_message}</p>

          <div class="flex flex-wrap justify-end gap-sm pt-md">
            <.button
              type="button"
              variant={:ghost}
              phx-click={JS.push("close_bulk_modal")}
            >
              Cancel
            </.button>
            <button
              type="submit"
              name="mode"
              value="assign_regardless"
              class="rounded-pill bg-brand-700 hover:bg-brand text-white text-sm font-medium px-md py-xs"
            >
              Assign even if previously completed
            </button>
            <button
              type="submit"
              name="mode"
              value="skip_if_previously_assigned"
              class="rounded-pill bg-brand-700 hover:bg-brand text-white text-sm font-medium px-md py-xs"
            >
              Assign only if never assigned
            </button>
          </div>
        </form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("bulk_assign", %{"template_id" => tid, "mode" => mode}, socket) do
    %{actor: actor, current_school: school, selected_student_ids: ids} = socket.assigns

    case Assessments.bulk_assign_survey(
           ids,
           tid,
           String.to_existing_atom(mode),
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
        {:noreply, assign(socket, error_message: "Bulk assign failed.")}
    end
  end
end
