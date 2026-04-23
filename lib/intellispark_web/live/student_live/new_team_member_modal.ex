defmodule IntellisparkWeb.StudentLive.NewTeamMemberModal do
  @moduledoc """
  Sectioned modal for adding a team member to a student. Top level
  splits into Family / community (drill-in) and School staff
  (searchable multi-select). Calls Teams.create_team_membership/4 for
  staff and Teams.create_external_person + create_key_connection for
  family/community contacts. Broadcasts :team_member_added on success.
  """

  use IntellisparkWeb, :live_component

  alias Intellispark.Teams
  alias Intellispark.Teams.ExternalPerson

  @staff_roles ~w(teacher coach counselor social_worker clinician other)a

  @relationship_kinds ~w(parent guardian sibling coach community_partner other)a

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:view, fn -> :menu end)
     |> assign_new(:error_message, fn -> nil end)
     |> assign_new(:selected_staff, fn -> %{} end)
     |> assign_new(:staff_search, fn -> "" end)
     |> assign(staff_roles: @staff_roles, relationship_kinds: @relationship_kinds)
     |> load_external_persons()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id={@id} on_cancel={JS.push("close_new_team_member_modal")} show>
        <:title>{title_for(@view)}</:title>
        <.menu_view :if={@view == :menu} myself={@myself} />
        <.family_view
          :if={@view == :family}
          myself={@myself}
          external_persons={@external_persons}
        />
        <.family_new_view
          :if={@view == :family_new}
          myself={@myself}
          relationship_kinds={@relationship_kinds}
        />
        <.staff_view
          :if={@view == :staff}
          myself={@myself}
          staff={@staff}
          staff_search={@staff_search}
          staff_roles={@staff_roles}
          selected_staff={@selected_staff}
        />
        <p :if={@error_message} class="text-xs text-chocolate pt-sm">{@error_message}</p>
      </.modal>
    </div>
    """
  end

  attr :myself, :any, required: true

  defp menu_view(assigns) do
    ~H"""
    <ul class="divide-y divide-abbey/10">
      <li>
        <button
          type="button"
          phx-click="goto"
          phx-value-view="family"
          phx-target={@myself}
          class="flex w-full items-center justify-between gap-md p-md text-left hover:bg-whitesmoke"
        >
          <span class="space-y-1">
            <span class="block text-sm font-medium text-abbey">Family / community members</span>
            <span class="block text-xs text-azure">
              Parents, guardians, siblings, coaches, partners
            </span>
          </span>
          <span class="hero-chevron-right-mini text-azure"></span>
        </button>
      </li>
      <li>
        <button
          type="button"
          phx-click="goto"
          phx-value-view="staff"
          phx-target={@myself}
          class="flex w-full items-center justify-between gap-md p-md text-left hover:bg-whitesmoke"
        >
          <span class="space-y-1">
            <span class="block text-sm font-medium text-abbey">School staff</span>
            <span class="block text-xs text-azure">Teachers, counselors, clinicians</span>
          </span>
          <span class="hero-chevron-right-mini text-azure"></span>
        </button>
      </li>
    </ul>
    """
  end

  attr :myself, :any, required: true
  attr :external_persons, :list, required: true

  defp family_view(assigns) do
    ~H"""
    <div class="space-y-sm">
      <.back_link target={@myself} />
      <p class="text-xs text-azure">Pick an existing contact or add a new one.</p>

      <ul :if={@external_persons != []} class="divide-y divide-abbey/10">
        <li :for={ep <- @external_persons}>
          <button
            type="button"
            phx-click="pick_external_person"
            phx-value-id={ep.id}
            phx-target={@myself}
            class="flex w-full items-center justify-between p-sm text-left hover:bg-whitesmoke"
          >
            <span>
              <span class="block text-sm text-abbey">{ep.first_name} {ep.last_name}</span>
              <span class="block text-xs text-azure capitalize">
                {humanize_atom(ep.relationship_kind)}
              </span>
            </span>
            <span class="text-xs text-brand">Add</span>
          </button>
        </li>
      </ul>

      <p :if={@external_persons == []} class="text-xs text-azure italic">
        No family or community contacts yet.
      </p>

      <div class="pt-sm">
        <.button
          type="button"
          variant={:primary}
          phx-click="goto"
          phx-value-view="family_new"
          phx-target={@myself}
        >
          + Add new family/community contact
        </.button>
      </div>
    </div>
    """
  end

  attr :myself, :any, required: true
  attr :relationship_kinds, :list, required: true

  defp family_new_view(assigns) do
    ~H"""
    <form
      phx-submit="create_external_person"
      phx-target={@myself}
      class="space-y-sm"
    >
      <.back_link target={@myself} />

      <div class="grid grid-cols-2 gap-sm">
        <label class="block">
          <span class="text-xs text-abbey">First name</span>
          <input
            name="first_name"
            type="text"
            required
            class="w-full rounded border border-abbey/20 p-xs text-sm"
          />
        </label>
        <label class="block">
          <span class="text-xs text-abbey">Last name</span>
          <input
            name="last_name"
            type="text"
            required
            class="w-full rounded border border-abbey/20 p-xs text-sm"
          />
        </label>
      </div>

      <label class="block">
        <span class="text-xs text-abbey">Relationship</span>
        <select
          name="relationship_kind"
          required
          class="w-full rounded border border-abbey/20 p-xs text-sm"
        >
          <option :for={k <- @relationship_kinds} value={Atom.to_string(k)}>
            {humanize_atom(k)}
          </option>
        </select>
      </label>

      <label class="block">
        <span class="text-xs text-abbey">Email (optional)</span>
        <input
          name="email"
          type="email"
          class="w-full rounded border border-abbey/20 p-xs text-sm"
        />
      </label>

      <label class="block">
        <span class="text-xs text-abbey">Phone (optional)</span>
        <input
          name="phone"
          type="tel"
          class="w-full rounded border border-abbey/20 p-xs text-sm"
        />
      </label>

      <div class="flex justify-end gap-sm pt-md">
        <.button
          type="button"
          variant={:ghost}
          phx-click="goto"
          phx-value-view="family"
          phx-target={@myself}
        >
          Cancel
        </.button>
        <.button type="submit" variant={:primary}>Add to team</.button>
      </div>
    </form>
    """
  end

  attr :myself, :any, required: true
  attr :staff, :list, required: true
  attr :staff_search, :string, required: true
  attr :staff_roles, :list, required: true
  attr :selected_staff, :map, required: true

  defp staff_view(assigns) do
    filtered = filter_staff(assigns.staff, assigns.staff_search)
    assigns = assign(assigns, filtered: filtered)

    ~H"""
    <div class="space-y-sm">
      <.back_link target={@myself} />

      <form phx-change="search_staff" phx-target={@myself}>
        <input
          type="search"
          name="q"
          value={@staff_search}
          placeholder="Search staff…"
          class="w-full rounded border border-abbey/20 p-xs text-sm"
        />
      </form>

      <ul class="max-h-72 overflow-y-auto divide-y divide-abbey/10">
        <li :for={s <- @filtered} class="flex items-center gap-sm p-sm">
          <input
            type="checkbox"
            id={"staff-#{s.id}"}
            checked={Map.has_key?(@selected_staff, s.id)}
            phx-click="toggle_staff"
            phx-value-id={s.id}
            phx-target={@myself}
          />
          <label for={"staff-#{s.id}"} class="flex-1 text-sm text-abbey">
            {staff_label(s)}
          </label>
          <select
            phx-change="set_staff_role"
            phx-target={@myself}
            name={"role[#{s.id}]"}
            disabled={!Map.has_key?(@selected_staff, s.id)}
            class="rounded border border-abbey/20 p-xs text-xs"
          >
            <option
              :for={r <- @staff_roles}
              value={Atom.to_string(r)}
              selected={selected_role(@selected_staff, s.id) == r}
            >
              {humanize_atom(r)}
            </option>
          </select>
        </li>
        <li :if={@filtered == []} class="p-sm text-xs italic text-azure">
          No matching staff.
        </li>
      </ul>

      <div class="flex justify-end gap-sm pt-md">
        <.button
          type="button"
          variant={:primary}
          phx-click="add_selected_staff"
          phx-target={@myself}
          disabled={@selected_staff == %{}}
        >
          Add selected ({map_size(@selected_staff)})
        </.button>
      </div>
    </div>
    """
  end

  attr :target, :any, required: true

  defp back_link(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="goto"
      phx-value-view="menu"
      phx-target={@target}
      class="text-xs text-azure underline hover:text-abbey"
    >
      ← Back
    </button>
    """
  end

  @impl true
  def handle_event("goto", %{"view" => v}, socket) do
    {:noreply, assign(socket, view: String.to_existing_atom(v), error_message: nil)}
  end

  def handle_event("search_staff", %{"q" => q}, socket) do
    {:noreply, assign(socket, staff_search: q)}
  end

  def handle_event("toggle_staff", %{"id" => uid}, socket) do
    selected = socket.assigns.selected_staff

    next =
      if Map.has_key?(selected, uid) do
        Map.delete(selected, uid)
      else
        Map.put(selected, uid, :teacher)
      end

    {:noreply, assign(socket, selected_staff: next)}
  end

  def handle_event("set_staff_role", params, socket) do
    role_map = Map.get(params, "role", %{})

    next =
      Enum.reduce(role_map, socket.assigns.selected_staff, fn {uid, role_str}, acc ->
        if Map.has_key?(acc, uid) do
          Map.put(acc, uid, String.to_existing_atom(role_str))
        else
          acc
        end
      end)

    {:noreply, assign(socket, selected_staff: next)}
  end

  def handle_event("add_selected_staff", _params, socket) do
    %{actor: actor, student: student, selected_staff: selected} = socket.assigns

    results =
      Enum.map(selected, fn {uid, role} ->
        Teams.create_team_membership(student.id, uid, role,
          actor: actor,
          tenant: student.school_id
        )
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        send(self(), {__MODULE__, :team_member_added})
        {:noreply, socket}

      {:error, err} ->
        {:noreply, assign(socket, error_message: format_error(err))}
    end
  end

  def handle_event("pick_external_person", %{"id" => ep_id}, socket) do
    %{actor: actor, student: student} = socket.assigns

    case Teams.create_key_connection_for_external_person(student.id, ep_id, %{},
           actor: actor,
           tenant: student.school_id
         ) do
      {:ok, _} ->
        send(self(), {__MODULE__, :team_member_added})
        {:noreply, socket}

      {:error, err} ->
        {:noreply, assign(socket, error_message: format_error(err))}
    end
  end

  def handle_event("create_external_person", params, socket) do
    %{actor: actor, student: student} = socket.assigns
    school_id = student.school_id

    relationship = String.to_existing_atom(params["relationship_kind"])

    extras =
      %{}
      |> maybe_put(:email, params["email"])
      |> maybe_put(:phone, params["phone"])

    with {:ok, ep} <-
           Teams.create_external_person(
             params["first_name"],
             params["last_name"],
             relationship,
             extras,
             actor: actor,
             tenant: school_id
           ),
         {:ok, _} <-
           Teams.create_key_connection_for_external_person(student.id, ep.id, %{},
             actor: actor,
             tenant: school_id
           ) do
      send(self(), {__MODULE__, :team_member_added})
      {:noreply, socket}
    else
      {:error, err} ->
        {:noreply, assign(socket, error_message: format_error(err))}
    end
  end

  defp load_external_persons(socket) do
    %{actor: actor, student: student} = socket.assigns

    rows =
      ExternalPerson
      |> Ash.Query.sort([:last_name, :first_name])
      |> Ash.read!(actor: actor, tenant: student.school_id)

    assign(socket, external_persons: rows)
  end

  defp filter_staff(staff, ""), do: staff

  defp filter_staff(staff, q) when is_binary(q) do
    needle = String.downcase(q)

    Enum.filter(staff, fn s ->
      label = s |> staff_label() |> to_string() |> String.downcase()
      String.contains?(label, needle)
    end)
  end

  defp selected_role(selected, uid), do: Map.get(selected, uid, :teacher)

  defp title_for(:menu), do: "New team member"
  defp title_for(:family), do: "Family / community members"
  defp title_for(:family_new), do: "Add family / community contact"
  defp title_for(:staff), do: "School staff"

  defp staff_label(%{first_name: f, last_name: l}) when is_binary(f) and is_binary(l),
    do: "#{f} #{l}"

  defp staff_label(%{email: email}), do: email
  defp staff_label(_), do: "Staff"

  defp humanize_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp format_error(%Ash.Error.Invalid{errors: errs}) do
    Enum.map_join(errs, ", ", fn e -> Map.get(e, :message) || inspect(e) end)
  end

  defp format_error(err), do: inspect(err)
end
