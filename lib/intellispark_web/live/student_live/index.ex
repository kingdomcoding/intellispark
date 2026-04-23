defmodule IntellisparkWeb.StudentLive.Index do
  @moduledoc """
  /students — All Students list. Row columns match screenshot 10-10-04:
  Student (N) | High-5s | Flags | Status | Supports | Tags. High-5s /
  Flags / Supports columns render 0 placeholders until Phase 4/5/6
  wire the real aggregates.
  """

  use IntellisparkWeb, :live_view

  alias Intellispark.Students
  alias Intellispark.Students.{CustomList, FilterSpec, Student}
  alias IntellisparkWeb.CustomListLive.Composer

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
       filter_spec: %FilterSpec{},
       from_list: nil,
       composer_open?: false
     )
     |> assign_tags_and_statuses()
     |> assign_students()}
  end

  @impl true
  def handle_params(%{"from_list" => list_id}, _uri, socket) do
    %{current_user: actor, current_school: school} = socket.assigns

    case Students.get_custom_list(list_id, actor: actor, tenant: school.id) do
      {:ok, list} ->
        {:noreply,
         socket
         |> assign(from_list: list, filter_spec: list.filters || %FilterSpec{})
         |> assign_students()}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "List not found.")
         |> assign(from_list: nil)}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

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

  def handle_event("open_bulk_modal", %{"action" => "insights"}, socket) do
    ids = socket.assigns.selected |> MapSet.to_list() |> Enum.join(",")

    {:noreply, push_navigate(socket, to: ~p"/insights?student_ids=#{ids}&return_to=/students")}
  end

  def handle_event("open_bulk_modal", %{"action" => action}, socket) do
    {:noreply, assign(socket, active_modal: action)}
  end

  def handle_event("close_bulk_modal", _params, socket) do
    {:noreply, assign(socket, active_modal: nil)}
  end

  def handle_event("search", %{"q" => q}, socket) do
    spec = %{socket.assigns.filter_spec | name_contains: blank_to_nil(q)}

    {:noreply,
     socket
     |> assign(filter_spec: spec)
     |> assign_students()}
  end

  def handle_event("filter_change", %{"filter" => params}, socket) do
    spec = merge_filter_params(socket.assigns.filter_spec, params)

    {:noreply,
     socket
     |> assign(filter_spec: spec)
     |> assign_students()}
  end

  def handle_event("filter_change", _params, socket) do
    spec = merge_filter_params(socket.assigns.filter_spec, %{})

    {:noreply,
     socket
     |> assign(filter_spec: spec)
     |> assign_students()}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(filter_spec: %FilterSpec{}, from_list: nil)
     |> assign_students()}
  end

  def handle_event("open_save_view", _params, socket) do
    {:noreply, assign(socket, composer_open?: true)}
  end

  def handle_event("close_composer", _params, socket) do
    {:noreply, assign(socket, composer_open?: false)}
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
  def handle_info(%Phoenix.Socket.Broadcast{topic: "students:school:" <> _}, socket) do
    {:noreply, assign_students(socket)}
  end

  def handle_info(%Ash.Notifier.Notification{}, socket) do
    {:noreply, assign_students(socket)}
  end

  def handle_info(
        {IntellisparkWeb.StudentLive.HighFiveBulkModal, {:bulk_success, n}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(active_modal: nil, selected: MapSet.new())
     |> put_flash(:info, "#{n} High 5 emails sent.")
     |> assign_students()}
  end

  def handle_info(
        {IntellisparkWeb.StudentLive.HighFiveBulkModal, {:bulk_partial, ok, failed}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(active_modal: nil, selected: MapSet.new())
     |> put_flash(
       :warning,
       "#{ok} sent. #{failed} failed (likely missing recipient emails)."
     )
     |> assign_students()}
  end

  def handle_info(
        {IntellisparkWeb.StudentLive.SurveyBulkModal, {:bulk_success, n}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(active_modal: nil, selected: MapSet.new())
     |> put_flash(:info, "#{n} surveys assigned.")
     |> assign_students()}
  end

  def handle_info(
        {IntellisparkWeb.StudentLive.SurveyBulkModal, {:bulk_partial, ok, failed}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(active_modal: nil, selected: MapSet.new())
     |> put_flash(:warning, "#{ok} assigned. #{failed} failed.")
     |> assign_students()}
  end

  def handle_info(
        {IntellisparkWeb.StudentLive.TeamBulkModal, {:bulk_success, n}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(active_modal: nil, selected: MapSet.new())
     |> put_flash(:info, "Team member added to #{n} students.")
     |> assign_students()}
  end

  def handle_info(
        {IntellisparkWeb.StudentLive.TeamBulkModal, {:bulk_partial, ok, failed}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(active_modal: nil, selected: MapSet.new())
     |> put_flash(
       :warning,
       "#{ok} added. #{failed} failed (likely already on team)."
     )
     |> assign_students()}
  end

  def handle_info({Composer, {:saved, :create, list}}, socket) do
    {:noreply,
     socket
     |> assign(composer_open?: false)
     |> put_flash(:info, "List saved.")
     |> push_navigate(to: ~p"/lists/#{list.id}")}
  end

  def handle_info({Composer, {:saved, :update, list}}, socket) do
    {:noreply,
     socket
     |> assign(composer_open?: false, from_list: list, filter_spec: list.filters)
     |> put_flash(:info, "List updated.")
     |> assign_students()}
  end

  def handle_info(_other, socket), do: {:noreply, socket}

  defp assign_students(socket) do
    %{current_user: actor, current_school: school, filter_spec: spec} = socket.assigns

    open_flags_query =
      Intellispark.Flags.Flag
      |> Ash.Query.filter(status != :closed)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.select([:id, :description, :short_description, :inserted_at])

    open_supports_query =
      Intellispark.Support.Support
      |> Ash.Query.filter(status in [:offered, :in_progress])
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.select([:id, :title, :inserted_at])

    students =
      Student
      |> Ash.Query.load([
        :display_name,
        :current_status,
        :open_flags_count,
        :open_supports_count,
        :recent_high_fives_count,
        {:flags, open_flags_query},
        {:supports, open_supports_query},
        tags: [:id, :name, :color]
      ])
      |> apply_filter_spec(spec)
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

  defp apply_filter_spec(query, %FilterSpec{} = spec) do
    query
    |> apply_name_search(spec.name_contains)
    |> apply_tag_ids(spec.tag_ids)
    |> apply_status_ids(spec.status_ids)
    |> apply_grade_levels(spec.grade_levels)
    |> apply_enrollment_statuses(spec.enrollment_statuses)
  end

  defp apply_filter_spec(query, _), do: query

  defp apply_name_search(query, nil), do: query
  defp apply_name_search(query, ""), do: query

  defp apply_name_search(query, term) when is_binary(term) do
    like = "%#{term}%"

    Ash.Query.filter(
      query,
      ilike(first_name, ^like) or ilike(last_name, ^like) or ilike(preferred_name, ^like)
    )
  end

  defp apply_tag_ids(query, []), do: query

  defp apply_tag_ids(query, ids) when is_list(ids) do
    Ash.Query.filter(query, exists(student_tags, tag_id in ^ids))
  end

  defp apply_status_ids(query, []), do: query

  defp apply_status_ids(query, ids) when is_list(ids) do
    Ash.Query.filter(query, current_status_id in ^ids)
  end

  defp apply_grade_levels(query, []), do: query

  defp apply_grade_levels(query, levels) when is_list(levels) do
    Ash.Query.filter(query, grade_level in ^levels)
  end

  defp apply_enrollment_statuses(query, []), do: query

  defp apply_enrollment_statuses(query, statuses) when is_list(statuses) do
    Ash.Query.filter(query, enrollment_status in ^statuses)
  end

  defp merge_filter_params(%FilterSpec{} = spec, params) when is_map(params) do
    %FilterSpec{
      spec
      | tag_ids: parse_uuid_list(params["tag_ids"]),
        status_ids: parse_uuid_list(params["status_ids"]),
        grade_levels: parse_int_list(params["grade_levels"]),
        enrollment_statuses: parse_enrollment_list(params["enrollment_statuses"])
    }
  end

  defp parse_uuid_list(nil), do: []
  defp parse_uuid_list(list) when is_list(list), do: Enum.reject(list, &(&1 in [nil, ""]))

  defp parse_int_list(nil), do: []

  defp parse_int_list(list) when is_list(list) do
    list
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.map(fn
      n when is_integer(n) -> n
      s when is_binary(s) -> String.to_integer(s)
    end)
  end

  defp parse_enrollment_list(nil), do: []

  defp parse_enrollment_list(list) when is_list(list) do
    valid = ~w(active inactive graduated withdrawn)a

    list
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.map(fn
      a when is_atom(a) -> a
      s when is_binary(s) -> String.to_existing_atom(s)
    end)
    |> Enum.filter(&(&1 in valid))
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(s) when is_binary(s), do: s

  defp empty_filter_spec?(%FilterSpec{} = spec) do
    spec.tag_ids == [] and spec.status_ids == [] and spec.grade_levels == [] and
      spec.enrollment_statuses == [] and spec.name_contains in [nil, ""] and
      not spec.no_high_five_in_30_days and not spec.has_open_survey_assignment and
      no_dimension_filters?(spec)
  end

  defp no_dimension_filters?(%FilterSpec{} = spec) do
    Intellispark.Indicators.Dimension.all()
    |> Enum.all?(&is_nil(Map.get(spec, &1)))
  end

  defp save_label(nil), do: "Save view as…"
  defp save_label(%CustomList{}), do: "Save view"

  defp composer_mode(nil), do: :create
  defp composer_mode(%CustomList{}), do: :update

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

  defp flag_entries(flags) do
    Enum.map(flags, fn f ->
      f.short_description || truncate_text(f.description, 60)
    end)
  end

  defp support_entries(supports), do: Enum.map(supports, & &1.title)

  defp truncate_text(nil, _), do: ""

  defp truncate_text(text, max) when is_binary(text) do
    if String.length(text) > max, do: String.slice(text, 0, max) <> "…", else: text
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_school={@current_school}
      breadcrumb={%{label: "Back to my lists", path: ~p"/lists"}}
      onboarding_incomplete?={@onboarding_incomplete?}
    >
      <section class="container-lg py-xl space-y-md">
        <h1 class="text-display-md text-brand">All Students</h1>

        <.filter_bar
          search={@filter_spec.name_contains || ""}
          tag_ids={@filter_spec.tag_ids}
          status_ids={@filter_spec.status_ids}
          grade_levels={@filter_spec.grade_levels}
          enrollment_statuses={@filter_spec.enrollment_statuses}
          tags={@tags}
          statuses={@statuses}
          save_disabled?={empty_filter_spec?(@filter_spec)}
          save_label={save_label(@from_list)}
        />

        <div class="bg-white rounded-card shadow-card">
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
                <td class="px-md py-sm text-center">
                  <.count_badge value={s.recent_high_fives_count} variant={:high_fives} />
                </td>
                <td class="px-md py-sm text-center">
                  <.count_badge_with_popover
                    id={"student-#{s.id}-flags"}
                    value={s.open_flags_count}
                    variant={:flags}
                    entries={flag_entries(s.flags || [])}
                    empty_label="No open flags"
                  />
                </td>
                <td
                  class="px-md py-sm text-center cursor-pointer"
                  phx-click={JS.navigate(~p"/students/#{s.id}?return_to=/students")}
                >
                  <.status_chip_for_status :if={s.current_status} status={s.current_status} />
                </td>
                <td class="px-md py-sm text-center">
                  <.count_badge_with_popover
                    id={"student-#{s.id}-supports"}
                    value={s.open_supports_count}
                    variant={:supports}
                    entries={support_entries(s.supports || [])}
                    empty_label="No open supports"
                  />
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

        <.live_component
          :if={@active_modal == "high_fives"}
          module={IntellisparkWeb.StudentLive.HighFiveBulkModal}
          id="bulk-high-fives"
          actor={@current_user}
          current_school={@current_school}
          selected_student_ids={MapSet.to_list(@selected)}
        />

        <.live_component
          :if={@active_modal == "forms"}
          module={IntellisparkWeb.StudentLive.SurveyBulkModal}
          id="bulk-forms"
          actor={@current_user}
          current_school={@current_school}
          selected_student_ids={MapSet.to_list(@selected)}
        />

        <.live_component
          :if={@active_modal == "team"}
          module={IntellisparkWeb.StudentLive.TeamBulkModal}
          id="bulk-team"
          actor={@current_user}
          current_school={@current_school}
          selected_student_ids={MapSet.to_list(@selected)}
        />

        <.live_component
          :if={@composer_open?}
          module={IntellisparkWeb.CustomListLive.Composer}
          id="save-view-composer"
          mode={composer_mode(@from_list)}
          actor={@current_user}
          current_school={@current_school}
          filter_spec={@filter_spec}
          list={@from_list}
        />
      </section>
    </Layouts.app>
    """
  end
end
