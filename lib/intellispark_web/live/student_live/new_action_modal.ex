defmodule IntellisparkWeb.StudentLive.NewActionModal do
  @moduledoc """
  Modal for creating a follow-up Action on a student. Drives an
  AshPhoenix.Form for Support.Action.:create; on submit sends
  {__MODULE__, :action_created} upstream so the parent LiveView can
  close the modal and refresh its Actions panel.
  """

  use IntellisparkWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn -> build_form(assigns) end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id={@id} on_cancel={JS.push("close_new_action_modal")} show>
        <:title>New action for {@student.display_name}</:title>

        <.form
          for={@form}
          phx-change="validate"
          phx-submit="save"
          phx-target={@myself}
          class="space-y-sm"
        >
          <.input
            field={@form[:description]}
            type="textarea"
            label="What needs to happen?"
          />
          <.input
            field={@form[:assignee_id]}
            type="select"
            label="Assignee"
            options={Enum.map(@staff, &{&1.email, &1.id})}
            prompt="— pick an assignee —"
          />
          <.input field={@form[:due_on]} type="date" label="Due date (optional)" />

          <p :if={@error_message} class="text-xs text-chocolate">{@error_message}</p>

          <div class="flex justify-end gap-sm pt-md">
            <.button
              type="button"
              variant={:ghost}
              phx-click={JS.push("close_new_action_modal")}
            >
              Cancel
            </.button>
            <.button type="submit" variant={:primary}>Create action</.button>
          </div>
        </.form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"action" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, form: form, error_message: nil)}
  end

  def handle_event("save", %{"action" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _action} ->
        send(self(), {__MODULE__, :action_created})
        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp build_form(assigns) do
    Intellispark.Support.Action
    |> AshPhoenix.Form.for_create(:create,
      actor: assigns.actor,
      tenant: assigns.student.school_id,
      domain: Intellispark.Support,
      as: "action",
      transform_params: fn _form, params, _ ->
        Map.put(params, "student_id", assigns.student.id)
      end
    )
    |> to_form()
  end
end
