defmodule IntellisparkWeb.StudentLive.Show do
  @moduledoc false
  use IntellisparkWeb, :live_view

  alias Intellispark.Flags.Flag
  alias Intellispark.Students
  alias Intellispark.Students.{Student, StudentStatus, StudentTag}

  require Ash.Query

  @impl true
  def mount(%{"id" => id} = params, _session, socket) do
    %{current_user: actor, current_school: school} = socket.assigns

    with {:ok, student} <- Students.get_student(id, actor: actor, tenant: school.id),
         {:ok, student} <- load_student(student, actor, school) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Intellispark.PubSub, "students:school:#{school.id}")
        Phoenix.PubSub.subscribe(Intellispark.PubSub, "students:#{student.id}")
        Phoenix.PubSub.subscribe(Intellispark.PubSub, "flags:student:#{student.id}")
      end

      {:ok,
       socket
       |> assign(
         page_title: to_string(student.display_name),
         student: student,
         breadcrumb: resolve_breadcrumb(params["return_to"], actor, school),
         tags: Students.list_tags!(actor: actor, tenant: school.id),
         statuses: Students.list_statuses!(actor: actor, tenant: school.id),
         timeline: load_timeline(student, school),
         flags: load_flags(student, actor, school),
         flag_types: Intellispark.Flags.list_flag_types!(actor: actor, tenant: school.id),
         staff: load_staff(school),
         edit_modal_open?: false,
         edit_form: nil,
         new_flag_open?: false,
         active_flag_id: nil,
         flag_detail_open?: false
       )
       |> allow_upload(:photo,
         accept: ~w(.png .jpg .jpeg .webp),
         max_entries: 1,
         max_file_size: 5_000_000,
         auto_upload: true,
         progress: &handle_photo_progress/3
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

  def handle_event("open_new_flag_modal", _params, socket) do
    {:noreply, assign(socket, new_flag_open?: true)}
  end

  def handle_event("close_new_flag_modal", _params, socket) do
    {:noreply, assign(socket, new_flag_open?: false)}
  end

  def handle_event("open_flag_sheet", %{"id" => id}, socket) do
    {:noreply, assign(socket, active_flag_id: id, flag_detail_open?: true)}
  end

  def handle_event("close_flag_sheet", _params, socket) do
    {:noreply, assign(socket, flag_detail_open?: false, active_flag_id: nil)}
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

  def handle_event("save_photo", _params, socket), do: {:noreply, socket}

  @allowed_mime ~w(image/png image/jpeg image/webp)
  @ext_of %{"image/png" => "png", "image/jpeg" => "jpg", "image/webp" => "webp"}

  defp handle_photo_progress(:photo, entry, socket) do
    if entry.done? do
      %{current_user: actor, current_school: school, student: student} = socket.assigns

      result =
        if entry.client_type in @allowed_mime do
          ext = Map.fetch!(@ext_of, entry.client_type)
          basename = "#{Ash.UUID.generate()}.#{ext}"

          dir =
            Path.join([
              :code.priv_dir(:intellispark),
              "static",
              "uploads",
              "students",
              student.id
            ])

          File.mkdir_p!(dir)
          dest = Path.join(dir, basename)

          consume_uploaded_entry(socket, entry, fn %{path: tmp} ->
            File.cp!(tmp, dest)
            {:ok, "/uploads/students/#{student.id}/#{basename}"}
          end)
          |> then(fn url ->
            Ash.update(student, %{photo_url: url},
              action: :update,
              actor: actor,
              tenant: school.id
            )
          end)
        else
          {:error, :unsupported_mime}
        end

      case result do
        {:ok, _updated} ->
          {:noreply,
           socket
           |> put_flash(:info, "Photo updated.")
           |> reload_student()}

        {:error, _err} ->
          {:noreply, put_flash(socket, :error, "Could not upload photo.")}
      end
    else
      {:noreply, socket}
    end
  end

  defp uploading?(upload_config) do
    Enum.any?(upload_config.entries, fn entry -> entry.progress < 100 end)
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

  def handle_info({IntellisparkWeb.StudentLive.NewFlagModal, :flag_opened}, socket) do
    {:noreply,
     socket
     |> assign(new_flag_open?: false)
     |> put_flash(:info, "Flag opened.")
     |> reload_student()}
  end

  def handle_info({IntellisparkWeb.StudentLive.FlagDetailSheet, :flag_changed}, socket) do
    {:noreply, reload_student(socket)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "students:" <> _}, socket) do
    {:noreply, reload_student(socket)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "flags:" <> _}, socket) do
    {:noreply, reload_student(socket)}
  end

  def handle_info(%Ash.Notifier.Notification{}, socket) do
    {:noreply, reload_student(socket)}
  end

  def handle_info(_other, socket), do: {:noreply, socket}

  defp reload_student(socket) do
    %{current_user: actor, current_school: school, student: student} = socket.assigns

    case Students.get_student(student.id, actor: actor, tenant: school.id) do
      {:ok, fresh} ->
        {:ok, loaded} = load_student(fresh, actor, school)

        assign(socket,
          student: loaded,
          timeline: load_timeline(loaded, school),
          flags: load_flags(loaded, actor, school)
        )

      _ ->
        socket
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

  defp load_flags(student, actor, school) do
    Flag
    |> Ash.Query.filter(student_id == ^student.id and status not in [:closed, :reopened, :draft])
    |> Ash.Query.load([:flag_type, :assignee_count, :comment_count])
    |> Ash.Query.set_tenant(school.id)
    |> Ash.Query.sort([{:inserted_at, :desc}])
    |> Ash.read!(actor: actor)
  end

  defp load_timeline(student, school) do
    student_versions =
      Student.Version
      |> Ash.Query.filter(version_source_id == ^student.id)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&Map.put(&1, :__kind__, :student_event))

    tag_versions =
      StudentTag.Version
      |> Ash.Query.filter(student_id == ^student.id)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&Map.put(&1, :__kind__, :tag_event))

    status_versions =
      StudentStatus.Version
      |> Ash.Query.filter(student_id == ^student.id)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&Map.put(&1, :__kind__, :status_event))

    (student_versions ++ tag_versions ++ status_versions)
    |> Enum.sort_by(& &1.version_inserted_at, {:desc, DateTime})
    |> Enum.take(20)
  end

  defp load_student(student, actor, school) do
    Ash.load(
      student,
      [
        :display_name,
        :initials,
        :age_in_years,
        :current_status,
        :open_flags_count,
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
        <.header_card student={@student} uploads={@uploads} />

        <div class="grid grid-cols-1 md:grid-cols-3 gap-md">
          <div class="md:col-span-2 space-y-md">
            <.future_panel
              title="High-5s"
              icon="hero-hand-raised"
              phase="Phase 5"
              message="High-5s — quick positive acknowledgements — arrive in Phase 5."
            />
            <.future_panel
              title="Supports"
              icon="hero-heart"
              phase="Phase 6"
              message="Structured support plans + intervention tracking arrive in Phase 6."
            />
            <.future_panel
              title="Notes"
              icon="hero-document-text"
              phase="Phase 8"
              message="Case notes arrive in Phase 8."
            />
          </div>

          <div class="space-y-md">
            <.profile_card student={@student} />

            <.flags_panel flags={@flags} />

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
                id="inline-tag-editor"
                student={@student}
                tags={@tags}
                actor={@current_user}
              />
            </div>
          </div>
        </div>

        <.activity_card timeline={@timeline} />
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

      <.live_component
        :if={@new_flag_open?}
        module={IntellisparkWeb.StudentLive.NewFlagModal}
        id="new-flag-modal"
        student={@student}
        actor={@current_user}
        flag_types={@flag_types}
        staff={@staff}
        error_message={nil}
      />

      <.live_component
        :if={@flag_detail_open? and @active_flag_id}
        module={IntellisparkWeb.StudentLive.FlagDetailSheet}
        id={"flag-sheet-#{@active_flag_id}"}
        flag_id={@active_flag_id}
        actor={@current_user}
        tenant={@current_school.id}
      />
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :icon, :string, required: true
  attr :phase, :string, required: true
  attr :message, :string, required: true

  defp future_panel(assigns) do
    ~H"""
    <div class="bg-white rounded-card shadow-card p-md space-y-sm">
      <div class="flex items-center justify-between">
        <h2 class="text-sm font-semibold text-abbey">{@title}</h2>
        <button
          type="button"
          disabled
          title={"Arrives in #{@phase}"}
          aria-disabled="true"
          class="inline-flex items-center gap-1 rounded-pill border border-abbey/20 bg-lightgrey px-md py-1 text-xs font-medium text-azure cursor-not-allowed"
        >
          + New {@title |> String.downcase() |> String.trim_trailing("s")}
        </button>
      </div>
      <.empty_state icon={@icon} message={@message} />
    </div>
    """
  end

  attr :timeline, :list, required: true

  defp activity_card(assigns) do
    ~H"""
    <div class="bg-white rounded-card shadow-card p-md space-y-sm">
      <h2 class="text-sm font-semibold text-abbey">Activity</h2>
      <ol :if={@timeline != []} class="space-y-sm">
        <li :for={entry <- @timeline} class="flex gap-sm items-start">
          <span class={["#{icon_for(entry.__kind__)} size-4 text-azure mt-1"]}></span>
          <div class="flex-1">
            <p class="text-sm text-abbey">{summarise(entry)}</p>
            <p class="text-xs text-azure">{relative_time(entry.version_inserted_at)}</p>
          </div>
        </li>
      </ol>
      <.empty_state :if={@timeline == []} icon="hero-clock" message="No activity yet." />
    </div>
    """
  end

  defp icon_for(:student_event), do: "hero-pencil"
  defp icon_for(:tag_event), do: "hero-tag"
  defp icon_for(:status_event), do: "hero-chart-bar"

  defp summarise(%{__kind__: :student_event, version_action_name: name}) do
    case name do
      :create -> "Profile created"
      :update -> "Profile updated"
      :set_status -> "Status changed"
      :clear_status -> "Status cleared"
      :upload_photo -> "Photo updated"
      :remove_tag -> "Tag removed"
      other -> "Student #{other}"
    end
  end

  defp summarise(%{__kind__: :tag_event, version_action_name: :create}), do: "Tag applied"
  defp summarise(%{__kind__: :tag_event, version_action_name: :destroy}), do: "Tag removed"
  defp summarise(%{__kind__: :tag_event}), do: "Tag change"

  defp summarise(%{__kind__: :status_event, version_action_name: :create}), do: "Status set"
  defp summarise(%{__kind__: :status_event, version_action_name: :clear}), do: "Status cleared"
  defp summarise(%{__kind__: :status_event}), do: "Status change"

  defp relative_time(%DateTime{} = ts) do
    diff = DateTime.diff(DateTime.utc_now(), ts, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86_400)}d ago"
      true -> Calendar.strftime(ts, "%b %-d, %Y")
    end
  end

  defp relative_time(_), do: ""

  defp format_upload_error(:too_large), do: "File is too large (5MB max)."
  defp format_upload_error(:not_accepted), do: "File type not accepted (PNG / JPEG / WEBP only)."
  defp format_upload_error(:too_many_files), do: "Only one file at a time."
  defp format_upload_error(err), do: to_string(err)

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
  attr :uploads, :map, required: true

  defp header_card(assigns) do
    ~H"""
    <section class="bg-white rounded-card shadow-card p-lg flex flex-wrap gap-md">
      <form phx-change="save_photo" class="flex flex-col items-center gap-xs">
        <label class="flex flex-col items-center gap-xs cursor-pointer">
          <.live_file_input upload={@uploads.photo} class="hidden" />
          <.avatar
            name={to_string(@student.display_name)}
            image_url={@student.photo_url}
            size={:xl}
          />
          <span class="text-xs text-brand underline">Change photo</span>
        </label>
        <p
          :for={err <- upload_errors(@uploads.photo)}
          class="text-xs text-chocolate"
        >
          {format_upload_error(err)}
        </p>
        <p :if={uploading?(@uploads.photo)} class="text-xs text-azure">
          Uploading…
        </p>
      </form>

      <div class="flex-1 min-w-[20rem] space-y-sm">
        <div class="flex items-start justify-between gap-sm">
          <div>
            <h1 class="text-display-sm text-brand">{@student.display_name}</h1>
            <p class="text-azure text-sm">
              Grade {@student.grade_level}<span :if={@student.external_id}> · {@student.external_id}</span>
            </p>
          </div>
          <button
            type="button"
            phx-click="open_edit_modal"
            class="text-sm text-brand underline hover:text-brand-700"
          >
            Edit profile
          </button>
        </div>

        <div class="flex items-center gap-sm flex-wrap">
          <.status_chip_for_status :if={@student.current_status} status={@student.current_status} />
          <.tag_chip :for={tag <- @student.tags || []} label={tag.name} />
        </div>

        <div class="flex gap-lg pt-sm border-t border-abbey/10">
          <div class="flex items-center gap-sm">
            <.count_badge value={0} variant={:high_fives} />
            <span class="text-azure text-xs">High-5s</span>
          </div>
          <div class="flex items-center gap-sm">
            <.count_badge value={@student.open_flags_count} variant={:flags} />
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

  attr :flags, :list, required: true

  defp flags_panel(assigns) do
    ~H"""
    <div class="bg-white rounded-card shadow-card p-md space-y-sm">
      <div class="flex items-center justify-between">
        <h2 class="text-sm font-semibold text-abbey">
          Flags ({length(@flags)})
        </h2>
        <button
          type="button"
          phx-click="open_new_flag_modal"
          class="text-xs text-brand underline hover:text-brand-700"
        >
          + New flag
        </button>
      </div>

      <ol :if={@flags != []} class="space-y-xs">
        <li
          :for={flag <- @flags}
          id={"flag-#{flag.id}"}
          phx-click="open_flag_sheet"
          phx-value-id={flag.id}
          class="cursor-pointer flex items-start gap-sm p-xs rounded hover:bg-whitesmoke"
        >
          <span
            class="inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-full mt-1"
            style={"background: #{flag.flag_type.color}; opacity: 0.2"}
          >
            <span class="hero-flag size-3.5 text-abbey"></span>
          </span>
          <div class="flex-1 min-w-0 space-y-0.5">
            <p class="text-sm font-medium text-abbey truncate">{flag.flag_type.name}</p>
            <p class="text-xs text-azure line-clamp-2">{flag.short_description}</p>
            <div class="flex items-center gap-xs pt-0.5">
              <.flag_status_pill status={flag.status} />
              <span class="text-[0.6875rem] text-azure">
                {flag.assignee_count} assignee<span :if={flag.assignee_count != 1}>s</span>
              </span>
            </div>
          </div>
        </li>
      </ol>

      <.empty_state
        :if={@flags == []}
        icon="hero-flag"
        message="No open flags for this student."
      />
    </div>
    """
  end

  attr :status, :atom, required: true

  defp flag_status_pill(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-pill border px-2 py-0.5 text-[0.6875rem] font-medium",
      status_pill_classes(@status)
    ]}>
      {status_label(@status)}
    </span>
    """
  end

  defp status_pill_classes(:draft), do: "border-abbey/30 text-abbey bg-white"
  defp status_pill_classes(:open), do: "border-brand text-brand bg-white"
  defp status_pill_classes(:assigned), do: "border-brand-700 text-brand-700 bg-brand/5"

  defp status_pill_classes(:under_review),
    do: "border-chocolate text-chocolate bg-chocolate/5"

  defp status_pill_classes(:pending_followup),
    do: "border-status-followup-border text-status-followup-text bg-white"

  defp status_pill_classes(:closed),
    do: "border-status-resolved-border text-status-resolved-text bg-white"

  defp status_pill_classes(:reopened),
    do: "border-status-active-border text-status-active-text bg-white"

  defp status_label(:draft), do: "Draft"
  defp status_label(:open), do: "Open"
  defp status_label(:assigned), do: "Assigned"
  defp status_label(:under_review), do: "Under review"
  defp status_label(:pending_followup), do: "Pending follow-up"
  defp status_label(:closed), do: "Closed"
  defp status_label(:reopened), do: "Reopened"
end
