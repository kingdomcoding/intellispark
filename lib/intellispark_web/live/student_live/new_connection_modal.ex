defmodule IntellisparkWeb.StudentLive.NewConnectionModal do
  @moduledoc """
  Modal for adding a Key Connection — a meaningful relationship between
  a student and a staff person. Source defaults to `:added_manually`;
  optional note carries provenance text.
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
      <.modal id={@id} on_cancel={JS.push("close_new_connection_modal")} show>
        <:title>New connection</:title>

        <form phx-submit="save" phx-target={@myself} class="space-y-sm">
          <label class="text-sm font-medium text-abbey">Connected staff</label>
          <select
            name="connected_user_id"
            required
            class="w-full rounded border border-abbey/20 p-xs text-sm"
          >
            <option value="">— select staff —</option>
            <option :for={s <- @staff} value={s.id}>
              {staff_label(s)}
            </option>
          </select>

          <label class="text-sm font-medium text-abbey">Note (optional)</label>
          <textarea
            name="note"
            rows="2"
            placeholder="e.g., self-reported on Insightfull Sep 14, 2020"
            class="w-full rounded border border-abbey/20 p-xs text-sm"
          ></textarea>

          <p :if={@error_message} class="text-xs text-chocolate">{@error_message}</p>

          <div class="flex justify-end gap-sm pt-md">
            <.button
              type="button"
              variant={:ghost}
              phx-click={JS.push("close_new_connection_modal")}
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
  def handle_event("save", %{"connected_user_id" => uid, "note" => note}, socket) do
    %{actor: actor, student: student} = socket.assigns

    extras = %{note: blank_to_nil(note), source: :added_manually}

    case Teams.create_key_connection(student.id, uid, extras,
           actor: actor,
           tenant: student.school_id
         ) do
      {:ok, _} ->
        send(self(), {__MODULE__, :connection_added})
        {:noreply, socket}

      {:error, err} ->
        {:noreply, assign(socket, error_message: inspect_error(err))}
    end
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil

  defp blank_to_nil(s) when is_binary(s) do
    case String.trim(s) do
      "" -> nil
      other -> other
    end
  end

  defp staff_label(%{first_name: f, last_name: l}) when is_binary(f) and is_binary(l),
    do: "#{f} #{l}"

  defp staff_label(%{email: email}), do: email
  defp staff_label(_), do: "Staff"

  defp inspect_error(%Ash.Error.Invalid{errors: errs}) do
    Enum.map_join(errs, ", ", fn %{message: m} -> m end)
  end

  defp inspect_error(err), do: inspect(err)
end
