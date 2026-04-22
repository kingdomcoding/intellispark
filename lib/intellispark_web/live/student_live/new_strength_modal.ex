defmodule IntellisparkWeb.StudentLive.NewStrengthModal do
  @moduledoc """
  Modal for adding a strength to a student. Single text input + Add
  button; `display_order` is auto-assigned by `DefaultDisplayOrder` so
  bullets render in insertion order.
  """

  use IntellisparkWeb, :live_component

  alias Intellispark.Teams

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:error_message, fn -> nil end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id={@id} on_cancel={JS.push("close_new_strength_modal")} show>
        <:title>New strength</:title>

        <form phx-submit="save" phx-target={@myself} class="space-y-sm">
          <label class="text-sm font-medium text-abbey">Strength</label>
          <input
            type="text"
            name="description"
            required
            placeholder="e.g., Creativity"
            class="w-full rounded border border-abbey/20 p-xs text-sm"
          />

          <p :if={@error_message} class="text-xs text-chocolate">{@error_message}</p>

          <div class="flex justify-end gap-sm pt-md">
            <.button
              type="button"
              variant={:ghost}
              phx-click={JS.push("close_new_strength_modal")}
            >
              Cancel
            </.button>
            <.button type="submit" variant={:primary}>Add</.button>
          </div>
        </form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("save", %{"description" => desc}, socket) do
    %{actor: actor, student: student} = socket.assigns

    case Teams.create_strength(student.id, desc,
           actor: actor,
           tenant: student.school_id
         ) do
      {:ok, _} ->
        send(self(), {__MODULE__, :strength_added})
        {:noreply, socket}

      {:error, err} ->
        {:noreply, assign(socket, error_message: inspect_error(err))}
    end
  end

  defp inspect_error(%Ash.Error.Invalid{errors: errs}) do
    Enum.map_join(errs, ", ", fn %{message: m} -> m end)
  end

  defp inspect_error(err), do: inspect(err)
end
