defmodule IntellisparkWeb.StudentLive.NewHighFiveModal do
  @moduledoc """
  Modal for sending a High 5 to a student. Supports two modes — pick a
  template (autofills title + body) or write a custom message.
  Submits through `HighFive.:send_to_student`; the notifier enqueues
  the Oban email delivery job.
  """

  use IntellisparkWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:mode, fn -> :template end)
     |> assign_new(:selected_template_id, fn -> nil end)
     |> assign_new(:form, fn -> build_form(assigns) end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id={@id} on_cancel={JS.push("close_new_high_five_modal")} show>
        <:title>New High 5 for {@student.display_name}</:title>

        <div class="flex items-center gap-sm pb-sm border-b border-abbey/10">
          <.mode_pill
            label="From template"
            mode={:template}
            active={@mode == :template}
            target={@myself}
          />
          <.mode_pill
            label="Custom message"
            mode={:custom}
            active={@mode == :custom}
            target={@myself}
          />
        </div>

        <.form
          for={@form}
          phx-change="validate"
          phx-submit="save"
          phx-target={@myself}
          class="space-y-sm pt-sm"
        >
          <.input
            :if={@mode == :template}
            field={@form[:template_id]}
            type="select"
            label="Template"
            options={Enum.map(@templates, &{"#{&1.title} (#{&1.category})", &1.id})}
            prompt="— pick a template —"
          />

          <.input field={@form[:title]} label="Title" />
          <.input field={@form[:body]} type="textarea" rows="4" label="Message" />

          <.input
            field={@form[:recipient_email]}
            type="email"
            label="Send to"
          />

          <p :if={@error_message} class="text-xs text-chocolate">{@error_message}</p>

          <div class="flex justify-end gap-sm pt-md">
            <.button
              type="button"
              variant={:ghost}
              phx-click={JS.push("close_new_high_five_modal")}
            >
              Cancel
            </.button>
            <.button type="submit" variant={:primary}>Send High 5</.button>
          </div>
        </.form>
      </.modal>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :mode, :atom, required: true
  attr :active, :boolean, required: true
  attr :target, :any, required: true

  defp mode_pill(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="set_mode"
      phx-value-mode={@mode}
      phx-target={@target}
      class={[
        "rounded-pill border px-md py-1 text-xs font-medium",
        @active && "bg-brand/5 border-brand text-brand",
        !@active && "border-abbey/20 text-azure hover:bg-whitesmoke"
      ]}
    >
      {@label}
    </button>
    """
  end

  @impl true
  def handle_event("set_mode", %{"mode" => "template"}, socket) do
    {:noreply, assign(socket, mode: :template)}
  end

  def handle_event("set_mode", %{"mode" => "custom"}, socket) do
    {:noreply, assign(socket, mode: :custom, selected_template_id: nil)}
  end

  def handle_event("validate", %{"high_five" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    selected_template_id =
      case Map.get(params, "template_id") do
        "" -> nil
        nil -> nil
        id -> id
      end

    form =
      maybe_autofill_from_template(
        form,
        selected_template_id,
        socket.assigns.selected_template_id,
        socket.assigns.templates
      )

    {:noreply,
     assign(socket,
       form: form,
       selected_template_id: selected_template_id,
       error_message: nil
     )}
  end

  def handle_event("save", %{"high_five" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _high_five} ->
        send(self(), {__MODULE__, :high_five_sent})
        {:noreply, socket}

      {:error, form} ->
        {:noreply,
         assign(socket,
           form: form,
           error_message: "Check the fields below and try again."
         )}
    end
  end

  defp build_form(assigns) do
    initial =
      case assigns.student do
        %{email: email} when is_binary(email) and email != "" ->
          %{"recipient_email" => email}

        _ ->
          %{}
      end

    Intellispark.Recognition.HighFive
    |> AshPhoenix.Form.for_create(:send_to_student,
      actor: assigns.actor,
      tenant: assigns.student.school_id,
      domain: Intellispark.Recognition,
      as: "high_five",
      transform_params: fn _form, params, _ ->
        Map.put(params, "student_id", assigns.student.id)
      end
    )
    |> AshPhoenix.Form.validate(initial)
    |> to_form()
  end

  defp maybe_autofill_from_template(form, nil, _prev, _templates), do: form

  defp maybe_autofill_from_template(form, tid, tid, _templates), do: form

  defp maybe_autofill_from_template(form, tid, _prev, templates) do
    case Enum.find(templates, &(&1.id == tid)) do
      nil ->
        form

      template ->
        params = Map.merge(form.params, %{"title" => template.title, "body" => template.body})

        form.source
        |> AshPhoenix.Form.validate(params)
        |> to_form()
    end
  end
end
