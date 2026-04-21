defmodule IntellisparkWeb.StudentLive.NewSurveyModal do
  @moduledoc """
  Modal for assigning a survey template to a single student. Opened
  from the Forms & Surveys panel on the Student Hub. On submit calls
  `Assessments.assign_survey/3` and sends `:survey_assigned` upstream.
  """

  use IntellisparkWeb, :live_component

  alias Intellispark.Assessments

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign_new(:error_message, fn -> nil end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id={@id} on_cancel={JS.push("close_new_survey_modal")} show>
        <:title>New form assignment</:title>

        <form phx-submit="assign" phx-target={@myself} class="space-y-sm">
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

          <div class="flex justify-end gap-sm pt-md">
            <.button
              type="button"
              variant={:ghost}
              phx-click={JS.push("close_new_survey_modal")}
            >
              Cancel
            </.button>
            <.button type="submit" variant={:primary}>Assign</.button>
          </div>
        </form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("assign", %{"template_id" => template_id}, socket) do
    %{actor: actor, student: student} = socket.assigns

    case Assessments.assign_survey(student.id, template_id,
           actor: actor,
           tenant: student.school_id
         ) do
      {:ok, _assignment} ->
        send(self(), {__MODULE__, :survey_assigned})
        {:noreply, socket}

      {:error, err} ->
        {:noreply,
         assign(socket,
           error_message: "Could not assign: #{inspect_error(err)}"
         )}
    end
  end

  defp inspect_error(%Ash.Error.Invalid{errors: errs}) do
    errs
    |> Enum.map(fn
      %{message: m} when is_binary(m) -> m
      other -> inspect(other)
    end)
    |> Enum.join(", ")
  end

  defp inspect_error(err), do: inspect(err)
end
