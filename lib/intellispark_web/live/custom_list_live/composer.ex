defmodule IntellisparkWeb.CustomListLive.Composer do
  @moduledoc """
  Shared composer used by /students "Save view" modal + /lists "Rename"
  modal. Handles :create (filter_spec known, list nil) and :update
  (list known, filter_spec optional) in one form. Form fields are
  limited to name / description / shared? — `filters` is injected via
  transform_params on submit.
  """

  use IntellisparkWeb, :live_component

  alias Intellispark.Students.{CustomList, FilterSpec}

  @impl true
  def update(assigns, socket) do
    form = build_form(assigns)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:error_message, fn -> nil end)
     |> assign(form: form)}
  end

  defp build_form(%{mode: :create} = assigns) do
    spec = assigns[:filter_spec] || %FilterSpec{}

    CustomList
    |> AshPhoenix.Form.for_create(:create,
      actor: assigns.actor,
      tenant: assigns.current_school.id,
      domain: Intellispark.Students,
      as: "list",
      transform_params: fn _form, params, _ ->
        Map.put(params, "filters", filters_to_params(spec))
      end
    )
    |> to_form()
  end

  defp build_form(%{mode: :update, list: list} = assigns) do
    spec = assigns[:filter_spec]

    list
    |> AshPhoenix.Form.for_update(:update,
      actor: assigns.actor,
      tenant: assigns.current_school.id,
      domain: Intellispark.Students,
      as: "list",
      transform_params: fn _form, params, _ ->
        case spec do
          nil -> params
          _ -> Map.put(params, "filters", filters_to_params(spec))
        end
      end
    )
    |> to_form()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id={@id} on_cancel={JS.push("close_composer")} show>
        <:title>{title(@mode)}</:title>

        <.form
          for={@form}
          id="list-composer-form"
          phx-submit="submit"
          phx-change="validate"
          phx-target={@myself}
          class="space-y-sm"
        >
          <.input field={@form[:name]} label="List name" required />
          <.input
            field={@form[:description]}
            label="Description (optional)"
            type="textarea"
            rows="2"
          />
          <.input
            field={@form[:shared?]}
            label="Share with everyone at this school"
            type="checkbox"
          />

          <div
            :if={show_summary?(assigns)}
            class="rounded border border-abbey/10 bg-whitesmoke p-sm space-y-xs"
          >
            <p class="text-xs font-semibold text-azure">Filters in this view</p>
            <.filter_summary filter_spec={@filter_spec} />
          </div>

          <p :if={@error_message} class="text-xs text-chocolate">{@error_message}</p>

          <div class="flex justify-end gap-sm pt-md">
            <.button
              type="button"
              variant={:ghost}
              phx-click={JS.push("close_composer")}
            >
              Cancel
            </.button>
            <.button type="submit" variant={:primary}>Save</.button>
          </div>
        </.form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"list" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("submit", %{"list" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, list} ->
        send(self(), {__MODULE__, {:saved, socket.assigns.mode, list}})
        {:noreply, socket}

      {:error, form} ->
        {:noreply,
         assign(socket,
           form: form,
           error_message: "Please check the fields and try again."
         )}
    end
  end

  attr :filter_spec, :map, default: nil

  defp filter_summary(assigns) do
    ~H"""
    <ul class="text-xs text-abbey space-y-0.5">
      <li :for={{k, v} <- non_empty_filters(@filter_spec)}>
        <span class="font-medium">{humanize_filter_key(k)}:</span>
        <span class="text-azure">{format_filter_value(v)}</span>
      </li>
      <li :if={non_empty_filters(@filter_spec) == []} class="text-azure italic">
        No filters active.
      </li>
    </ul>
    """
  end

  defp show_summary?(%{mode: :create}), do: true
  defp show_summary?(%{filter_spec: spec}) when not is_nil(spec), do: true
  defp show_summary?(_), do: false

  defp non_empty_filters(nil), do: []

  @filter_keys ~w(tag_ids status_ids grade_levels enrollment_statuses name_contains
                  no_high_five_in_30_days has_open_survey_assignment
                  belonging connection decision_making engagement readiness
                  relationship_skills relationships_adult relationships_networks
                  relationships_peer self_awareness self_management
                  social_awareness well_being)a

  defp non_empty_filters(spec) when is_map(spec) do
    @filter_keys
    |> Enum.map(&{&1, Map.get(spec, &1)})
    |> Enum.reject(fn
      {_, nil} -> true
      {_, []} -> true
      {_, ""} -> true
      {_, false} -> true
      _ -> false
    end)
  end

  defp humanize_filter_key(:tag_ids), do: "Tags"
  defp humanize_filter_key(:status_ids), do: "Status"
  defp humanize_filter_key(:grade_levels), do: "Grade levels"
  defp humanize_filter_key(:enrollment_statuses), do: "Enrollment"
  defp humanize_filter_key(:name_contains), do: "Name contains"
  defp humanize_filter_key(:no_high_five_in_30_days), do: "No High 5 in 30 days"
  defp humanize_filter_key(:has_open_survey_assignment), do: "Has open survey"

  defp humanize_filter_key(dim) when is_atom(dim) do
    if Intellispark.Indicators.Dimension.valid?(dim) do
      "#{Intellispark.Indicators.Dimension.humanize(dim)} level"
    else
      dim |> Atom.to_string() |> String.capitalize()
    end
  end

  defp format_filter_value(v) when is_list(v) do
    Enum.map_join(v, ", ", &format_filter_value/1)
  end

  defp format_filter_value(true), do: "yes"
  defp format_filter_value(v) when is_atom(v), do: Atom.to_string(v)
  defp format_filter_value(v), do: to_string(v)

  defp filters_to_params(spec) when is_map(spec) do
    Map.new(@filter_keys, &{&1, Map.get(spec, &1)})
  end

  defp filters_to_params(_), do: %{}

  defp title(:create), do: "Save view as…"
  defp title(:update), do: "Rename list"
end
