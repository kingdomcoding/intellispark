defmodule IntellisparkWeb.StudentLive.TeamBulkModal do
  @moduledoc """
  Bulk-assign a team member (staff + role) to N selected students. Uses
  `Ash.bulk_create/4` with `notify?: true` so the per-student Hub
  PubSub channels light up. Reports `{:bulk_success, n}` or
  `{:bulk_partial, ok, failed}` upstream.
  """

  use IntellisparkWeb, :live_component

  alias Intellispark.Teams.TeamMembership

  require Ash.Query

  @roles ~w(teacher coach counselor social_worker clinician family community_partner other)a

  @impl true
  def update(assigns, socket) do
    staff = load_staff(assigns.current_school)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(staff: staff, roles: @roles, error_message: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id={@id} on_cancel={JS.push("close_bulk_modal")} show>
        <:title>
          Assign a team member to {length(@selected_student_ids)} students
        </:title>

        <form phx-submit="bulk_add" phx-target={@myself} class="space-y-sm">
          <label class="text-sm font-medium text-abbey">Staff person</label>
          <select
            name="user_id"
            required
            class="w-full rounded border border-abbey/20 p-xs text-sm"
          >
            <option value="">— select staff —</option>
            <option :for={s <- @staff} value={s.id}>
              {staff_label(s)}
            </option>
          </select>

          <label class="text-sm font-medium text-abbey">Role</label>
          <select
            name="role"
            required
            class="w-full rounded border border-abbey/20 p-xs text-sm"
          >
            <option :for={r <- @roles} value={Atom.to_string(r)}>
              {humanize_role(r)}
            </option>
          </select>

          <p :if={@error_message} class="text-xs text-chocolate">{@error_message}</p>

          <div class="flex justify-end gap-sm pt-md">
            <.button
              type="button"
              variant={:ghost}
              phx-click={JS.push("close_bulk_modal")}
            >
              Cancel
            </.button>
            <.button type="submit" variant={:primary}>
              Add to {length(@selected_student_ids)}
            </.button>
          </div>
        </form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("bulk_add", %{"user_id" => uid, "role" => role_str}, socket) do
    %{actor: actor, current_school: school, selected_student_ids: ids} = socket.assigns
    role = String.to_existing_atom(role_str)

    payloads =
      Enum.map(ids, fn sid ->
        %{student_id: sid, user_id: uid, role: role, source: :manual}
      end)

    result =
      Ash.bulk_create(payloads, TeamMembership, :create,
        actor: actor,
        tenant: school.id,
        return_records?: true,
        return_errors?: true,
        stop_on_error?: false,
        notify?: true
      )

    case result do
      %Ash.BulkResult{records: records, errors: errs}
      when is_list(records) and (is_nil(errs) or errs == []) ->
        send(self(), {__MODULE__, {:bulk_success, length(records)}})
        {:noreply, socket}

      %Ash.BulkResult{records: records, errors: errs} when is_list(errs) ->
        send(
          self(),
          {__MODULE__, {:bulk_partial, length(records || []), length(errs)}}
        )

        {:noreply, socket}

      _ ->
        {:noreply, assign(socket, error_message: "Bulk add failed. Check permissions.")}
    end
  end

  defp load_staff(school) do
    Intellispark.Accounts.UserSchoolMembership
    |> Ash.Query.filter(school_id == ^school.id)
    |> Ash.Query.load(:user)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.user)
    |> Enum.uniq_by(& &1.id)
  end

  defp staff_label(%{first_name: f, last_name: l}) when is_binary(f) and is_binary(l),
    do: "#{f} #{l}"

  defp staff_label(%{email: email}), do: email
  defp staff_label(_), do: "Staff"

  defp humanize_role(:teacher), do: "Teacher"
  defp humanize_role(:coach), do: "Coach"
  defp humanize_role(:counselor), do: "Counselor"
  defp humanize_role(:social_worker), do: "Social Worker"
  defp humanize_role(:clinician), do: "Clinician"
  defp humanize_role(:family), do: "Family member"
  defp humanize_role(:community_partner), do: "Community partner"
  defp humanize_role(:other), do: "Other"
end
