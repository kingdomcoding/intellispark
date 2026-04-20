defmodule IntellisparkWeb.StudentLive.Index do
  @moduledoc """
  /students — All Students list. Row columns match screenshot 10-10-04:
  Student (N) | High-5s | Flags | Status | Supports | Tags. High-5s /
  Flags / Supports columns render 0 placeholders until Phase 4/5/6
  wire the real aggregates.
  """

  use IntellisparkWeb, :live_view

  alias Intellispark.Students
  alias Intellispark.Students.Student

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    %{current_school: school} = socket.assigns

    if connected?(socket) do
      Phoenix.PubSub.subscribe(
        Intellispark.PubSub,
        "students:school:#{school.id}"
      )
    end

    {:ok,
     socket
     |> assign(
       page_title: "All Students",
       selected: MapSet.new(),
       active_modal: nil,
       search: ""
     )
     |> assign_tags_and_statuses()
     |> assign_students()}
  end

  @impl true
  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected =
      if MapSet.member?(socket.assigns.selected, id),
        do: MapSet.delete(socket.assigns.selected, id),
        else: MapSet.put(socket.assigns.selected, id)

    {:noreply, assign(socket, selected: selected)}
  end

  def handle_event("toggle_select_all", _params, socket) do
    all_ids = Enum.map(socket.assigns.students, & &1.id) |> MapSet.new()

    selected =
      if MapSet.equal?(socket.assigns.selected, all_ids),
        do: MapSet.new(),
        else: all_ids

    {:noreply, assign(socket, selected: selected)}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, selected: MapSet.new())}
  end

  def handle_event("open_bulk_modal", %{"action" => action}, socket) do
    {:noreply, assign(socket, active_modal: action)}
  end

  def handle_event("close_bulk_modal", _params, socket) do
    {:noreply, assign(socket, active_modal: nil)}
  end

  def handle_event("toggle_filters", _params, socket) do
    {:noreply,
     put_flash(socket, :info, "Structured filters arrive in Phase 3 — use the search box for now.")}
  end

  def handle_event("search", %{"q" => q}, socket) do
    {:noreply,
     socket
     |> assign(search: q)
     |> assign_students()}
  end

  def handle_event("apply_tag", %{"tag_id" => tag_id}, socket) do
    %{current_user: actor, current_school: school, selected: selected} = socket.assigns
    student_ids = MapSet.to_list(selected)

    case Students.apply_tag_to_students(tag_id, student_ids,
           actor: actor,
           tenant: school.id
         ) do
      {:ok, tag} ->
        {success, errors} = bulk_counts(tag)
        flash_msg = bulk_flash("tag", success, errors)

        {:noreply,
         socket
         |> put_flash(:info, flash_msg)
         |> assign(selected: MapSet.new(), active_modal: nil)
         |> assign_students()}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not apply the tag")
         |> assign(active_modal: nil)}
    end
  end

  def handle_event("set_status", %{"student_id" => student_id, "status_id" => status_id}, socket) do
    %{current_user: actor, current_school: school} = socket.assigns
    {:ok, student} = Ash.get(Student, student_id, tenant: school.id, actor: actor)

    case Students.set_student_status(student, status_id, actor: actor, tenant: school.id) do
      {:ok, _} -> {:noreply, assign_students(socket)}
      _ -> {:noreply, put_flash(socket, :error, "Could not set status")}
    end
  end

  @impl true
  def handle_info(%Ash.Notifier.Notification{}, socket) do
    {:noreply, assign_students(socket)}
  end

  def handle_info(_other, socket), do: {:noreply, socket}

  defp assign_students(socket) do
    %{current_user: actor, current_school: school, search: search} = socket.assigns

    students =
      Student
      |> Ash.Query.load([:display_name, :current_status, tags: [:id, :name, :color]])
      |> maybe_apply_search(search)
      |> Ash.Query.sort([:last_name, :first_name])
      |> Ash.read!(actor: actor, tenant: school.id)

    assign(socket, students: students)
  end

  defp assign_tags_and_statuses(socket) do
    %{current_user: actor, current_school: school} = socket.assigns
    tags = Students.list_tags!(actor: actor, tenant: school.id)
    statuses = Students.list_statuses!(actor: actor, tenant: school.id)

    assign(socket, tags: tags, statuses: statuses)
  end

  defp maybe_apply_search(query, nil), do: query
  defp maybe_apply_search(query, ""), do: query

  defp maybe_apply_search(query, term) do
    like = "%#{term}%"

    Ash.Query.filter(
      query,
      ilike(first_name, ^like) or ilike(last_name, ^like) or ilike(preferred_name, ^like)
    )
  end

  defp bulk_counts(
         %{__metadata__: %{bulk_result: %Ash.BulkResult{status: :success, errors: nil}}} = _tag
       ) do
    {:unknown, 0}
  end

  defp bulk_counts(%{__metadata__: %{bulk_result: %Ash.BulkResult{} = result}}) do
    error_count = (result.errors || []) |> length()
    {:unknown, error_count}
  end

  defp bulk_counts(_tag), do: {:unknown, 0}

  defp bulk_flash(verb, _success, 0), do: "Bulk #{verb} applied"

  defp bulk_flash(verb, _success, error_count) do
    "Bulk #{verb} applied; #{error_count} record(s) could not be updated"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_school={@current_school}
      breadcrumb={%{label: "Back to my lists", path: ~p"/lists"}}
    >
      <section class="container-lg py-xl space-y-md">
        <h1 class="text-display-md text-brand">All Students</h1>

        <.filter_bar search={@search} on_search="search" />

        <div class="bg-white rounded-card shadow-card overflow-hidden">
          <table class="w-full text-sm text-left text-abbey">
            <thead class="border-b border-abbey/10 text-xs uppercase tracking-wide text-azure">
              <tr>
                <th class="px-md py-sm w-8">
                  <input type="checkbox" phx-click="toggle_select_all" />
                </th>
                <th class="px-md py-sm">Student ({length(@students)})</th>
                <th class="px-md py-sm text-center">High-5s</th>
                <th class="px-md py-sm text-center">Flags</th>
                <th class="px-md py-sm text-center">Status</th>
                <th class="px-md py-sm text-center">Supports</th>
                <th class="px-md py-sm">Tags</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-abbey/10">
              <tr
                :for={s <- @students}
                id={"student-#{s.id}"}
                class="hover:bg-whitesmoke/40"
              >
                <td class="px-md py-sm">
                  <input
                    type="checkbox"
                    checked={MapSet.member?(@selected, s.id)}
                    phx-click="toggle_select"
                    phx-value-id={s.id}
                  />
                </td>
                <td
                  class="px-md py-sm cursor-pointer"
                  phx-click={JS.navigate(~p"/students/#{s.id}?return_to=/students")}
                >
                  <.link
                    navigate={~p"/students/#{s.id}?return_to=/students"}
                    class="text-brand hover:text-brand-700"
                  >
                    {s.display_name}
                  </.link>
                </td>
                <td
                  class="px-md py-sm text-center cursor-pointer"
                  phx-click={JS.navigate(~p"/students/#{s.id}?return_to=/students")}
                >
                  <.count_badge value={0} variant={:high_fives} />
                </td>
                <td
                  class="px-md py-sm text-center cursor-pointer"
                  phx-click={JS.navigate(~p"/students/#{s.id}?return_to=/students")}
                >
                  <.count_badge value={0} variant={:flags} />
                </td>
                <td
                  class="px-md py-sm text-center cursor-pointer"
                  phx-click={JS.navigate(~p"/students/#{s.id}?return_to=/students")}
                >
                  <.status_chip_for_status :if={s.current_status} status={s.current_status} />
                </td>
                <td
                  class="px-md py-sm text-center cursor-pointer"
                  phx-click={JS.navigate(~p"/students/#{s.id}?return_to=/students")}
                >
                  <.count_badge value={0} variant={:supports} />
                </td>
                <td
                  class="px-md py-sm cursor-pointer"
                  phx-click={JS.navigate(~p"/students/#{s.id}?return_to=/students")}
                >
                  <.tag_chip_row tags={s.tags || []} max_visible={2} />
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <.live_component
          :if={MapSet.size(@selected) > 0}
          module={IntellisparkWeb.UI.BulkToolbar}
          id="bulk-toolbar"
          count={MapSet.size(@selected)}
        />

        <.live_component
          :if={@active_modal == "tag"}
          module={IntellisparkWeb.StudentLive.TagBulkModal}
          id="bulk-tag"
          selected_ids={@selected}
          tags={@tags}
        />

        <.live_component
          :if={@active_modal == "settings"}
          module={IntellisparkWeb.StudentLive.SettingsBulkModal}
          id="bulk-settings"
          selected_ids={@selected}
        />
      </section>
    </Layouts.app>
    """
  end
end
