defmodule IntellisparkWeb.StudentLive.NewTeamMemberModal do
  @moduledoc """
  Modal for adding a staff member to a student's team. Calls
  `Teams.create_team_membership/4` and broadcasts `:team_member_added`
  to the parent LiveView on success.
  """

  use IntellisparkWeb, :live_component

  alias Intellispark.Teams

  @roles ~w(teacher coach counselor social_worker clinician family community_partner other)a

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:error_message, fn -> nil end)
     |> assign(roles: @roles)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id={@id} on_cancel={JS.push("close_new_team_member_modal")} show>
        <:title>New team member</:title>

        <form phx-submit="save" phx-target={@myself} class="space-y-sm">
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
              phx-click={JS.push("close_new_team_member_modal")}
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
  def handle_event("save", %{"user_id" => uid, "role" => role_str}, socket) do
    %{actor: actor, student: student} = socket.assigns

    case Teams.create_team_membership(student.id, uid, String.to_existing_atom(role_str),
           actor: actor,
           tenant: student.school_id
         ) do
      {:ok, _} ->
        send(self(), {__MODULE__, :team_member_added})
        {:noreply, socket}

      {:error, err} ->
        {:noreply, assign(socket, error_message: inspect_error(err))}
    end
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

  defp inspect_error(%Ash.Error.Invalid{errors: errs}) do
    Enum.map_join(errs, ", ", fn %{message: m} -> m end)
  end

  defp inspect_error(err), do: inspect(err)
end
