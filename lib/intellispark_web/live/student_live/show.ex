defmodule IntellisparkWeb.StudentLive.Show do
  @moduledoc false
  use IntellisparkWeb, :live_view

  alias Intellispark.Students

  require Ash.Query

  @impl true
  def mount(%{"id" => id} = params, _session, socket) do
    %{current_user: actor, current_school: school} = socket.assigns

    with {:ok, student} <- Students.get_student(id, actor: actor, tenant: school.id),
         {:ok, student} <- load_student(student, actor, school) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Intellispark.PubSub, "students:school:#{school.id}")
        Phoenix.PubSub.subscribe(Intellispark.PubSub, "students:#{student.id}")
      end

      {:ok,
       socket
       |> assign(
         page_title: to_string(student.display_name),
         student: student,
         breadcrumb: resolve_breadcrumb(params["return_to"], actor, school),
         tags: Students.list_tags!(actor: actor, tenant: school.id),
         statuses: Students.list_statuses!(actor: actor, tenant: school.id),
         timeline: [],
         edit_modal_open?: false,
         edit_form: nil
       )
       |> allow_upload(:photo,
         accept: ~w(.png .jpg .jpeg .webp),
         max_entries: 1,
         max_file_size: 5_000_000
       )}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Student not found")
         |> redirect(to: ~p"/students")}
    end
  end

  @impl true
  def handle_event("open_edit_modal", _params, socket) do
    form = build_edit_form(socket.assigns)
    {:noreply, assign(socket, edit_modal_open?: true, edit_form: form)}
  end

  def handle_event("close_edit_modal", _params, socket) do
    {:noreply, assign(socket, edit_modal_open?: false, edit_form: nil)}
  end

  def handle_event("validate_profile", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.edit_form, params)
    {:noreply, assign(socket, edit_form: form)}
  end

  def handle_event("save_profile", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.edit_form, params: params) do
      {:ok, _student} ->
        {:noreply,
         socket
         |> assign(edit_modal_open?: false, edit_form: nil)
         |> put_flash(:info, "Profile updated.")
         |> reload_student()}

      {:error, form} ->
        {:noreply, assign(socket, edit_form: form)}
    end
  end

  defp build_edit_form(%{student: student, current_user: actor, current_school: school}) do
    student
    |> AshPhoenix.Form.for_update(:update,
      actor: actor,
      tenant: school.id,
      domain: Intellispark.Students,
      as: "form"
    )
    |> to_form()
  end

  @impl true
  def handle_info({IntellisparkWeb.StudentLive.InlineTagEditor, {:tags_changed, id}}, socket)
      when socket.assigns.student.id == id do
    {:noreply, reload_student(socket)}
  end

  def handle_info({IntellisparkWeb.StudentLive.InlineStatusEditor, {:status_changed, id}}, socket)
      when socket.assigns.student.id == id do
    {:noreply, reload_student(socket)}
  end

  def handle_info(_other, socket), do: {:noreply, socket}

  defp reload_student(socket) do
    %{current_user: actor, current_school: school, student: student} = socket.assigns

    case Students.get_student(student.id, actor: actor, tenant: school.id) do
      {:ok, fresh} ->
        {:ok, loaded} = load_student(fresh, actor, school)
        assign(socket, student: loaded)

      _ ->
        socket
    end
  end

  defp load_student(student, actor, school) do
    Ash.load(
      student,
      [
        :display_name,
        :initials,
        :age_in_years,
        :current_status,
        tags: [:id, :name, :color]
      ],
      actor: actor,
      tenant: school.id
    )
  end

  defp resolve_breadcrumb("/students", _actor, _school),
    do: %{label: "Back to All Students", path: ~p"/students"}

  defp resolve_breadcrumb("/lists/" <> list_id, actor, school) do
    case Students.get_custom_list(list_id, actor: actor, tenant: school.id) do
      {:ok, list} -> %{label: "Back to #{list.name}", path: ~p"/lists/#{list.id}"}
      _ -> %{label: "Back to my lists", path: ~p"/lists"}
    end
  end

  defp resolve_breadcrumb("/lists", _actor, _school),
    do: %{label: "Back to my lists", path: ~p"/lists"}

  defp resolve_breadcrumb(_, _actor, _school),
    do: %{label: "Back to All Students", path: ~p"/students"}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_school={@current_school}
      breadcrumb={@breadcrumb}
    >
      <section class="container-lg py-xl space-y-md">
        <.header_card student={@student} tags={@tags} actor={@current_user} />

        <div class="grid grid-cols-1 md:grid-cols-3 gap-md">
          <div class="md:col-span-2 space-y-md">
            <.placeholder_card title="Flags" phase="Phase 4" />
            <.placeholder_card title="High-5s" phase="Phase 5" />
            <.placeholder_card title="Supports" phase="Phase 6" />
            <.placeholder_card title="Notes" phase="Phase 8" />
          </div>

          <div class="space-y-md">
            <.profile_card student={@student} />

            <div class="bg-white rounded-card shadow-card p-md space-y-sm">
              <h2 class="text-sm font-semibold text-abbey">Status</h2>
              <.live_component
                module={IntellisparkWeb.StudentLive.InlineStatusEditor}
                id="inline-status-editor"
                student={@student}
                statuses={@statuses}
                actor={@current_user}
              />
            </div>

            <div class="bg-white rounded-card shadow-card p-md space-y-sm">
              <h2 class="text-sm font-semibold text-abbey">Tags</h2>
              <.live_component
                module={IntellisparkWeb.StudentLive.InlineTagEditor}
                id="sidebar-tag-editor"
                student={@student}
                tags={@tags}
                actor={@current_user}
              />
            </div>
          </div>
        </div>

        <.placeholder_card title="Activity" phase="Phase I" />
      </section>

      <.modal
        :if={@edit_modal_open?}
        id="edit-profile"
        on_cancel={JS.push("close_edit_modal")}
        show
      >
        <:title>Edit profile</:title>
        <.form
          for={@edit_form}
          phx-change="validate_profile"
          phx-submit="save_profile"
          class="space-y-sm"
        >
          <.input field={@edit_form[:first_name]} label="First name" />
          <.input field={@edit_form[:last_name]} label="Last name" />
          <.input field={@edit_form[:preferred_name]} label="Preferred name" />
          <.input field={@edit_form[:date_of_birth]} type="date" label="Date of birth" />
          <.input field={@edit_form[:grade_level]} type="number" label="Grade" min="-1" max="16" />
          <.input
            field={@edit_form[:enrollment_status]}
            type="select"
            options={[
              {"Active", "active"},
              {"Inactive", "inactive"},
              {"Graduated", "graduated"},
              {"Withdrawn", "withdrawn"}
            ]}
            label="Enrollment status"
          />
          <.input field={@edit_form[:external_id]} label="External ID" />

          <div class="flex justify-end gap-sm pt-md">
            <.button type="button" variant={:ghost} phx-click="close_edit_modal">Cancel</.button>
            <.button type="submit" variant={:primary}>Save</.button>
          </div>
        </.form>
      </.modal>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :phase, :string, required: true

  defp placeholder_card(assigns) do
    ~H"""
    <div class="bg-white rounded-card shadow-card p-md">
      <h2 class="text-sm font-semibold text-abbey">{@title}</h2>
      <p class="text-xs text-azure mt-xs">Placeholder — filled in {@phase}.</p>
    </div>
    """
  end

  attr :student, :map, required: true

  defp profile_card(assigns) do
    ~H"""
    <div class="bg-white rounded-card shadow-card p-md space-y-sm">
      <div class="flex items-center justify-between">
        <h2 class="text-sm font-semibold text-abbey">Profile</h2>
        <button
          type="button"
          phx-click="open_edit_modal"
          class="text-xs text-brand underline hover:text-brand-700"
        >
          Edit
        </button>
      </div>
      <dl class="text-sm space-y-xs">
        <div class="flex justify-between gap-sm">
          <dt class="text-azure">DOB</dt>
          <dd class="text-abbey">
            {if @student.date_of_birth, do: Date.to_string(@student.date_of_birth), else: "—"}
          </dd>
        </div>
        <div :if={@student.age_in_years} class="flex justify-between gap-sm">
          <dt class="text-azure">Age</dt>
          <dd class="text-abbey">{@student.age_in_years}</dd>
        </div>
        <div class="flex justify-between gap-sm">
          <dt class="text-azure">Preferred</dt>
          <dd class="text-abbey">{@student.preferred_name || "—"}</dd>
        </div>
        <div class="flex justify-between gap-sm">
          <dt class="text-azure">Grade</dt>
          <dd class="text-abbey">{@student.grade_level || "—"}</dd>
        </div>
        <div class="flex justify-between gap-sm">
          <dt class="text-azure">Enrollment</dt>
          <dd class="text-abbey">{@student.enrollment_status}</dd>
        </div>
        <div class="flex justify-between gap-sm">
          <dt class="text-azure">External ID</dt>
          <dd class="text-abbey">{@student.external_id || "—"}</dd>
        </div>
      </dl>
    </div>
    """
  end

  attr :student, :map, required: true
  attr :tags, :list, required: true
  attr :actor, :map, required: true

  defp header_card(assigns) do
    ~H"""
    <section class="bg-white rounded-card shadow-card p-lg flex flex-wrap gap-md">
      <.avatar
        name={to_string(@student.display_name)}
        image_url={@student.photo_url}
        size={:lg}
      />

      <div class="flex-1 min-w-[20rem] space-y-sm">
        <div class="flex items-start justify-between gap-sm">
          <div>
            <h1 class="text-display-sm text-brand">{@student.display_name}</h1>
            <p class="text-azure text-sm">
              Grade {@student.grade_level}<span :if={@student.external_id}> · {@student.external_id}</span>
            </p>
          </div>
          <.button variant={:ghost} phx-click="open_edit_modal">Edit profile</.button>
        </div>

        <div class="flex items-center gap-sm flex-wrap">
          <.status_chip_for_status :if={@student.current_status} status={@student.current_status} />
          <.live_component
            module={IntellisparkWeb.StudentLive.InlineTagEditor}
            id="inline-tag-editor"
            student={@student}
            tags={@tags}
            actor={@actor}
          />
        </div>

        <div class="flex gap-lg pt-sm border-t border-abbey/10">
          <div class="flex items-center gap-sm">
            <.count_badge value={0} variant={:high_fives} />
            <span class="text-azure text-xs">High-5s</span>
          </div>
          <div class="flex items-center gap-sm">
            <.count_badge value={0} variant={:flags} />
            <span class="text-azure text-xs">Flags</span>
          </div>
          <div class="flex items-center gap-sm">
            <.count_badge value={0} variant={:supports} />
            <span class="text-azure text-xs">Supports</span>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
