defmodule IntellisparkWeb.StudentLive.NewHighFiveModal do
  @moduledoc """
  Modal for sending or re-sending a High 5. In `:create` mode it offers
  template-autofill and custom-message pills; in `:resend` mode it
  pre-fills title + body from an existing HighFive and routes the submit
  through the `:resend` action (edit-before-resend).
  """

  use IntellisparkWeb, :live_component

  @impl true
  def update(assigns, socket) do
    assigns = Map.put_new(assigns, :mode, :create)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:template_mode, fn -> :template end)
     |> assign_new(:selected_template_id, fn -> nil end)
     |> assign_new(:form, fn -> build_form(assigns) end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id={@id} on_cancel={JS.push(close_event(@mode))} show>
        <:title>{modal_title(@mode, @student)}</:title>

        <div :if={@mode == :create} class="flex items-center gap-sm pb-sm border-b border-abbey/10">
          <.mode_pill
            label="From template"
            mode={:template}
            active={@template_mode == :template}
            target={@myself}
          />
          <.mode_pill
            label="Custom message"
            mode={:custom}
            active={@template_mode == :custom}
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
            :if={@mode == :create and @template_mode == :template}
            field={@form[:template_id]}
            type="select"
            label="Template"
            options={Enum.map(@templates, &{"#{&1.title} (#{&1.category})", &1.id})}
            prompt="— pick a template —"
          />

          <.input field={@form[:title]} label="Title" />
          <IntellisparkWeb.Components.RichTextInput.rich_text_input
            name="high_five[body]"
            id={"high-five-body-#{@id}"}
            value={to_string(@form[:body].value || "")}
            label="Message"
            placeholder="Type your message…"
          />

          <.input
            :if={@mode == :create}
            field={@form[:recipient_email]}
            type="email"
            label="Send to"
          />

          <p :if={@error_message} class="text-xs text-chocolate">{@error_message}</p>

          <div class="flex justify-end gap-sm pt-md">
            <.button
              type="button"
              variant={:ghost}
              phx-click={JS.push(close_event(@mode))}
            >
              Cancel
            </.button>
            <.button type="submit" variant={:primary}>{submit_label(@mode)}</.button>
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
      phx-click="set_template_mode"
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
  def handle_event("set_template_mode", %{"mode" => "template"}, socket) do
    {:noreply, assign(socket, template_mode: :template)}
  end

  def handle_event("set_template_mode", %{"mode" => "custom"}, socket) do
    {:noreply, assign(socket, template_mode: :custom, selected_template_id: nil)}
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
        send(self(), {__MODULE__, message_for_mode(socket.assigns.mode)})
        {:noreply, socket}

      {:error, form} ->
        {:noreply,
         assign(socket,
           form: form,
           error_message: "Check the fields below and try again."
         )}
    end
  end

  defp build_form(%{mode: :resend, high_five: hf} = assigns) when not is_nil(hf) do
    hf
    |> AshPhoenix.Form.for_update(:resend,
      actor: assigns.actor,
      tenant: assigns.student.school_id,
      domain: Intellispark.Recognition,
      as: "high_five"
    )
    |> AshPhoenix.Form.validate(%{"title" => hf.title, "body" => hf.body})
    |> to_form()
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

  defp modal_title(:create, student), do: "New High 5 for #{student.display_name}"
  defp modal_title(:resend, student), do: "Re-send High 5 to #{student.display_name}"

  defp submit_label(:create), do: "Send High 5"
  defp submit_label(:resend), do: "Re-send"

  defp close_event(:create), do: "close_new_high_five_modal"
  defp close_event(:resend), do: "close_resend_high_five_modal"

  defp message_for_mode(:create), do: :high_five_sent
  defp message_for_mode(:resend), do: :high_five_resent
end
