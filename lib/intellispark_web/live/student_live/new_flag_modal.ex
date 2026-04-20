defmodule IntellisparkWeb.StudentLive.NewFlagModal do
  @moduledoc """
  Create-a-flag modal opened from the Student Hub Flags panel. Drives a
  two-step write: AshPhoenix.Form.submit for Flag.:create (lands in
  :draft), then Students.open_flag with the selected assignee_ids to
  transition into :open and fire the FlagAssigned notifier.
  """

  use IntellisparkWeb, :live_component

  alias Intellispark.Flags

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:selected_assignees, fn -> MapSet.new() end)
     |> assign_new(:form, fn -> build_form(assigns) end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id={@id} on_cancel={JS.push("close_new_flag_modal")} show>
        <:title>New flag for {@student.display_name}</:title>

        <.form
          for={@form}
          phx-change="validate"
          phx-submit="save"
          phx-target={@myself}
          class="space-y-sm"
        >
          <.input
            field={@form[:flag_type_id]}
            type="select"
            label="Type"
            options={Enum.map(@flag_types, &{&1.name, &1.id})}
            prompt="— pick a type —"
          />
          <.input
            field={@form[:description]}
            type="textarea"
            label="What's going on?"
          />
          <.input field={@form[:sensitive?]} type="checkbox" label="Sensitive (clinical roles only)" />
          <.input field={@form[:followup_at]} type="date" label="Follow up by (optional)" />

          <fieldset class="mt-md">
            <legend class="text-sm font-medium text-abbey mb-xs">Assignees</legend>
            <p :if={@staff == []} class="text-xs text-azure italic">
              No staff yet — invite someone via /admin first.
            </p>
            <ul :if={@staff != []} class="space-y-xs">
              <li :for={person <- @staff} class="flex items-center gap-xs">
                <label class="flex items-center gap-xs text-sm text-abbey cursor-pointer">
                  <input
                    type="checkbox"
                    checked={MapSet.member?(@selected_assignees, person.id)}
                    phx-click="toggle_assignee"
                    phx-value-id={person.id}
                    phx-target={@myself}
                  />
                  {person.email}
                </label>
              </li>
            </ul>
          </fieldset>

          <p :if={@error_message} class="text-xs text-chocolate">{@error_message}</p>

          <div class="flex justify-end gap-sm pt-md">
            <.button
              type="button"
              variant={:ghost}
              phx-click={JS.push("close_new_flag_modal")}
            >
              Cancel
            </.button>
            <.button type="submit" variant={:primary}>Open flag</.button>
          </div>
        </.form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"flag" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, form: form, error_message: nil)}
  end

  def handle_event("toggle_assignee", %{"id" => id}, socket) do
    selected =
      if MapSet.member?(socket.assigns.selected_assignees, id) do
        MapSet.delete(socket.assigns.selected_assignees, id)
      else
        MapSet.put(socket.assigns.selected_assignees, id)
      end

    {:noreply, assign(socket, selected_assignees: selected)}
  end

  def handle_event("save", %{"flag" => params}, socket) do
    %{actor: actor, student: student, selected_assignees: selected} = socket.assigns
    assignee_ids = MapSet.to_list(selected)

    cond do
      assignee_ids == [] ->
        {:noreply, assign(socket, error_message: "Pick at least one assignee.")}

      true ->
        case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
          {:ok, draft} ->
            case Flags.open_flag(draft, assignee_ids,
                   actor: actor,
                   tenant: student.school_id
                 ) do
              {:ok, _opened} ->
                send(self(), {__MODULE__, :flag_opened})
                {:noreply, socket}

              {:error, _err} ->
                {:noreply,
                 assign(socket,
                   error_message: "Could not open the flag. Try again or check permissions."
                 )}
            end

          {:error, form} ->
            {:noreply, assign(socket, form: form)}
        end
    end
  end

  defp build_form(assigns) do
    Intellispark.Flags.Flag
    |> AshPhoenix.Form.for_create(:create,
      actor: assigns.actor,
      tenant: assigns.student.school_id,
      domain: Intellispark.Flags,
      as: "flag",
      forms: [auto?: true],
      transform_params: fn _form, params, _ ->
        Map.put(params, "student_id", assigns.student.id)
      end
    )
    |> to_form()
  end
end
