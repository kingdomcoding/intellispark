defmodule IntellisparkWeb.StudentLive.NewSupportModal do
  @moduledoc """
  Modal for creating an intervention Support on a student. Creates the
  row in :offered state via AshPhoenix.Form. On success sends
  {__MODULE__, :support_created} upstream.
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
      <.modal id={@id} on_cancel={JS.push("close_new_support_modal")} show>
        <:title>New support for {@student.display_name}</:title>

        <.form
          for={@form}
          phx-change="validate"
          phx-submit="save"
          phx-target={@myself}
          class="space-y-sm"
        >
          <.input field={@form[:title]} label="Title" />
          <.input
            field={@form[:description]}
            type="textarea"
            label="Description (optional)"
          />
          <.input
            field={@form[:provider_staff_id]}
            type="select"
            label="Provider (optional)"
            options={Enum.map(@staff, &{&1.email, &1.id})}
            prompt="— unassigned —"
          />
          <div class="grid grid-cols-2 gap-sm">
            <.input field={@form[:starts_at]} type="date" label="Starts" />
            <.input field={@form[:ends_at]} type="date" label="Ends" />
          </div>

          <div class="flex justify-end gap-sm pt-md">
            <.button
              type="button"
              variant={:ghost}
              phx-click={JS.push("close_new_support_modal")}
            >
              Cancel
            </.button>
            <.button type="submit" variant={:primary}>Offer support</.button>
          </div>
        </.form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"support" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"support" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _support} ->
        send(self(), {__MODULE__, :support_created})
        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp build_form(assigns) do
    Intellispark.Support.Support
    |> AshPhoenix.Form.for_create(:create,
      actor: assigns.actor,
      tenant: assigns.student.school_id,
      domain: Intellispark.Support,
      as: "support",
      transform_params: fn _form, params, _ ->
        Map.put(params, "student_id", assigns.student.id)
      end
    )
    |> to_form()
  end
end
