defmodule IntellisparkWeb.StudentLive.Show do
  @moduledoc false
  use IntellisparkWeb, :live_view

  alias Intellispark.Assessments
  alias Intellispark.Assessments.SurveyAssignment
  alias Intellispark.Flags.Flag
  alias Intellispark.Recognition
  alias Intellispark.Recognition.HighFive
  alias Intellispark.Students
  alias Intellispark.Students.{Student, StudentStatus, StudentTag}
  alias Intellispark.Support
  alias Intellispark.Support.{Action, Note}
  alias Intellispark.Support.Support, as: SupportPlan
  alias Intellispark.Teams.{KeyConnection, Strength, TeamMembership}

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
        Phoenix.PubSub.subscribe(Intellispark.PubSub, "actions:student:#{student.id}")
        Phoenix.PubSub.subscribe(Intellispark.PubSub, "supports:student:#{student.id}")
        Phoenix.PubSub.subscribe(Intellispark.PubSub, "notes:student:#{student.id}")
        Phoenix.PubSub.subscribe(Intellispark.PubSub, "high_fives:student:#{student.id}")

        Phoenix.PubSub.subscribe(
          Intellispark.PubSub,
          "survey_assignments:student:#{student.id}"
        )

        Phoenix.PubSub.subscribe(
          Intellispark.PubSub,
          "indicator_scores:student:#{student.id}"
        )

        Phoenix.PubSub.subscribe(
          Intellispark.PubSub,
          "team_memberships:student:#{student.id}"
        )

        Phoenix.PubSub.subscribe(
          Intellispark.PubSub,
          "key_connections:student:#{student.id}"
        )

        Phoenix.PubSub.subscribe(
          Intellispark.PubSub,
          "strengths:student:#{student.id}"
        )
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
         actions: load_actions(student, actor, school),
         has_completed_actions?: has_completed_actions?(student, actor, school),
         supports: load_supports(student, actor, school),
         notes: load_notes(student, actor, school),
         note_composer_form: build_note_composer_form(student, actor, school),
         edit_note_id: nil,
         recent_high_fives: load_recent_high_fives(student, actor, school),
         has_more_high_fives?: has_more_high_fives?(student, actor, school),
         templates: load_templates(actor, school),
         survey_assignments: load_survey_assignments(student, actor, school),
         survey_templates: load_survey_templates(actor, school),
         new_survey_open?: false,
         flag_types: Intellispark.Flags.list_flag_types!(actor: actor, tenant: school.id),
         staff: load_staff(school),
         edit_modal_open?: false,
         edit_form: nil,
         new_flag_open?: false,
         active_flag_id: nil,
         flag_detail_open?: false,
         new_action_open?: false,
         new_support_open?: false,
         active_support_id: nil,
         support_detail_open?: false,
         new_high_five_open?: false,
         previous_high_fives_open?: false,
         strengths: load_strengths_for(student, actor, school),
         new_team_member_open?: false,
         new_connection_open?: false,
         new_strength_open?: false
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

  def handle_event("open_new_action_modal", _params, socket) do
    {:noreply, assign(socket, new_action_open?: true)}
  end

  def handle_event("close_new_action_modal", _params, socket) do
    {:noreply, assign(socket, new_action_open?: false)}
  end

  def handle_event("complete_action", %{"id" => id}, socket) do
    %{current_user: actor, current_school: school} = socket.assigns

    with {:ok, action} <- Support.get_action(id, actor: actor, tenant: school.id),
         {:ok, _} <- Support.complete_action(action, actor: actor, tenant: school.id) do
      {:noreply,
       socket
       |> put_flash(:info, "Action completed.")
       |> reload_actions()}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Could not complete action.")}
    end
  end

  def handle_event("open_completed_actions", _params, socket) do
    {:noreply, put_flash(socket, :info, "Completed action review lands in Phase 12.")}
  end

  def handle_event("open_new_support_modal", _params, socket) do
    {:noreply, assign(socket, new_support_open?: true)}
  end

  def handle_event("close_new_support_modal", _params, socket) do
    {:noreply, assign(socket, new_support_open?: false)}
  end

  def handle_event("open_support_sheet", %{"id" => id}, socket) do
    {:noreply, assign(socket, active_support_id: id, support_detail_open?: true)}
  end

  def handle_event("close_support_sheet", _params, socket) do
    {:noreply, assign(socket, support_detail_open?: false, active_support_id: nil)}
  end

  def handle_event("open_new_high_five_modal", _params, socket) do
    {:noreply, assign(socket, new_high_five_open?: true)}
  end

  def handle_event("close_new_high_five_modal", _params, socket) do
    {:noreply, assign(socket, new_high_five_open?: false)}
  end

  def handle_event("open_previous_high_fives", _params, socket) do
    {:noreply, assign(socket, previous_high_fives_open?: true)}
  end

  def handle_event("close_previous_high_fives", _params, socket) do
    {:noreply, assign(socket, previous_high_fives_open?: false)}
  end

  def handle_event("open_new_survey_modal", _params, socket) do
    {:noreply, assign(socket, new_survey_open?: true)}
  end

  def handle_event("close_new_survey_modal", _params, socket) do
    {:noreply, assign(socket, new_survey_open?: false)}
  end

  def handle_event("open_new_team_member_modal", _params, socket) do
    {:noreply, assign(socket, new_team_member_open?: true)}
  end

  def handle_event("close_new_team_member_modal", _params, socket) do
    {:noreply, assign(socket, new_team_member_open?: false)}
  end

  def handle_event("open_new_connection_modal", _params, socket) do
    {:noreply, assign(socket, new_connection_open?: true)}
  end

  def handle_event("close_new_connection_modal", _params, socket) do
    {:noreply, assign(socket, new_connection_open?: false)}
  end

  def handle_event("open_new_strength_modal", _params, socket) do
    {:noreply, assign(socket, new_strength_open?: true)}
  end

  def handle_event("close_new_strength_modal", _params, socket) do
    {:noreply, assign(socket, new_strength_open?: false)}
  end

  def handle_event("validate_note", %{"note" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.note_composer_form, params)
    {:noreply, assign(socket, note_composer_form: form)}
  end

  def handle_event("save_note", %{"note" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.note_composer_form, params: params) do
      {:ok, _note} ->
        %{current_user: actor, current_school: school, student: student} = socket.assigns

        {:noreply,
         socket
         |> assign(note_composer_form: build_note_composer_form(student, actor, school))
         |> put_flash(:info, "Note posted.")
         |> reload_notes()}

      {:error, form} ->
        {:noreply, assign(socket, note_composer_form: form)}
    end
  end

  def handle_event("pin_note", %{"id" => id}, socket) do
    transition_note(socket, id, &Support.pin_note/2, "Note pinned.")
  end

  def handle_event("unpin_note", %{"id" => id}, socket) do
    transition_note(socket, id, &Support.unpin_note/2, "Note unpinned.")
  end

  def handle_event("edit_note", %{"id" => id}, socket) do
    {:noreply, assign(socket, edit_note_id: id)}
  end

  def handle_event("cancel_edit_note", _params, socket) do
    {:noreply, assign(socket, edit_note_id: nil)}
  end

  def handle_event("save_edit_note", %{"id" => id, "body" => new_body}, socket) do
    %{current_user: actor, current_school: school} = socket.assigns

    with {:ok, note} <- Support.get_note(id, actor: actor, tenant: school.id),
         {:ok, _} <-
           Support.update_note(note, %{body: new_body}, actor: actor, tenant: school.id) do
      {:noreply,
       socket
       |> assign(edit_note_id: nil)
       |> put_flash(:info, "Note updated.")
       |> reload_notes()}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Could not update note.")}
    end
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

  defp transition_note(socket, id, fun, success_msg) do
    %{current_user: actor, current_school: school} = socket.assigns

    with {:ok, note} <- Support.get_note(id, actor: actor, tenant: school.id),
         {:ok, _} <- fun.(note, actor: actor, tenant: school.id) do
      {:noreply,
       socket
       |> put_flash(:info, success_msg)
       |> reload_notes()}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Could not update note.")}
    end
  end

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

  def handle_info({IntellisparkWeb.StudentLive.NewActionModal, :action_created}, socket) do
    {:noreply,
     socket
     |> assign(new_action_open?: false)
     |> put_flash(:info, "Action created.")
     |> reload_actions()}
  end

  def handle_info({IntellisparkWeb.StudentLive.NewSupportModal, :support_created}, socket) do
    {:noreply,
     socket
     |> assign(new_support_open?: false)
     |> put_flash(:info, "Support offered.")
     |> reload_student()}
  end

  def handle_info({IntellisparkWeb.StudentLive.SupportDetailSheet, :support_changed}, socket) do
    {:noreply, reload_student(socket)}
  end

  def handle_info({IntellisparkWeb.StudentLive.SupportDetailSheet, :support_closed}, socket) do
    {:noreply,
     socket
     |> assign(support_detail_open?: false, active_support_id: nil)
     |> reload_student()}
  end

  def handle_info({IntellisparkWeb.StudentLive.NewHighFiveModal, :high_five_sent}, socket) do
    {:noreply,
     socket
     |> assign(new_high_five_open?: false)
     |> put_flash(:info, "High 5 sent.")
     |> reload_high_fives()}
  end

  def handle_info({IntellisparkWeb.StudentLive.NewSurveyModal, :survey_assigned}, socket) do
    {:noreply,
     socket
     |> assign(new_survey_open?: false)
     |> put_flash(:info, "Form assigned.")
     |> reload_survey_assignments()}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "students:" <> _}, socket) do
    {:noreply, reload_student(socket)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "flags:" <> _}, socket) do
    {:noreply, reload_student(socket)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "actions:" <> _}, socket) do
    {:noreply, reload_actions(socket)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "supports:" <> _}, socket) do
    {:noreply, reload_student(socket)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "notes:" <> _}, socket) do
    {:noreply, reload_notes(socket)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "high_fives:" <> _}, socket) do
    {:noreply, reload_high_fives(socket)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "survey_assignments:" <> _}, socket) do
    {:noreply, reload_survey_assignments(socket)}
  end

  def handle_info({:indicator_scores_updated, _student_id}, socket) do
    {:noreply, reload_indicators(socket)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "team_memberships:" <> _}, socket) do
    {:noreply, reload_team(socket)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "key_connections:" <> _}, socket) do
    {:noreply, reload_key_connections(socket)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "strengths:" <> _}, socket) do
    {:noreply, reload_strengths(socket)}
  end

  def handle_info({IntellisparkWeb.StudentLive.NewTeamMemberModal, :team_member_added}, socket) do
    {:noreply,
     socket
     |> assign(new_team_member_open?: false)
     |> put_flash(:info, "Team member added.")
     |> reload_team()}
  end

  def handle_info({IntellisparkWeb.StudentLive.NewConnectionModal, :connection_added}, socket) do
    {:noreply,
     socket
     |> assign(new_connection_open?: false)
     |> put_flash(:info, "Connection added.")
     |> reload_key_connections()}
  end

  def handle_info({IntellisparkWeb.StudentLive.NewStrengthModal, :strength_added}, socket) do
    {:noreply,
     socket
     |> assign(new_strength_open?: false)
     |> put_flash(:info, "Strength added.")
     |> reload_strengths()}
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
          flags: load_flags(loaded, actor, school),
          actions: load_actions(loaded, actor, school),
          has_completed_actions?: has_completed_actions?(loaded, actor, school),
          supports: load_supports(loaded, actor, school),
          notes: load_notes(loaded, actor, school),
          recent_high_fives: load_recent_high_fives(loaded, actor, school),
          has_more_high_fives?: has_more_high_fives?(loaded, actor, school),
          survey_assignments: load_survey_assignments(loaded, actor, school)
        )

      _ ->
        socket
    end
  end

  defp reload_actions(socket) do
    %{current_user: actor, current_school: school, student: student} = socket.assigns

    assign(socket,
      actions: load_actions(student, actor, school),
      has_completed_actions?: has_completed_actions?(student, actor, school)
    )
  end

  defp reload_notes(socket) do
    %{current_user: actor, current_school: school, student: student} = socket.assigns

    assign(socket,
      notes: load_notes(student, actor, school),
      timeline: load_timeline(student, school)
    )
  end

  defp reload_high_fives(socket) do
    %{current_user: actor, current_school: school, student: student} = socket.assigns

    assign(socket,
      recent_high_fives: load_recent_high_fives(student, actor, school),
      has_more_high_fives?: has_more_high_fives?(student, actor, school),
      timeline: load_timeline(student, school)
    )
    |> reload_student()
  end

  defp reload_survey_assignments(socket) do
    %{current_user: actor, current_school: school, student: student} = socket.assigns

    assign(socket,
      survey_assignments: load_survey_assignments(student, actor, school),
      timeline: load_timeline(student, school)
    )
  end

  defp reload_indicators(socket) do
    %{current_user: actor, current_school: school, student: student} = socket.assigns

    reloaded =
      Ash.load!(
        student,
        Intellispark.Indicators.Dimension.all(),
        actor: actor,
        tenant: school.id
      )

    assign(socket, student: reloaded, timeline: load_timeline(student, school))
  end

  defp reload_team(socket) do
    %{current_user: actor, current_school: school, student: student} = socket.assigns

    reloaded =
      Ash.load!(
        student,
        [team_memberships: [:user, :added_by]],
        actor: actor,
        tenant: school.id
      )

    assign(socket, student: reloaded, timeline: load_timeline(student, school))
  end

  defp reload_key_connections(socket) do
    %{current_user: actor, current_school: school, student: student} = socket.assigns

    reloaded =
      Ash.load!(
        student,
        [key_connections: [:connected_user]],
        actor: actor,
        tenant: school.id
      )

    assign(socket, student: reloaded, timeline: load_timeline(student, school))
  end

  defp reload_strengths(socket) do
    %{current_user: actor, current_school: school, student: student} = socket.assigns

    assign(socket,
      strengths: load_strengths_for(student, actor, school),
      timeline: load_timeline(student, school)
    )
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
    |> Ash.Query.filter(student_id == ^student.id and status not in [:closed, :draft])
    |> Ash.Query.load([:flag_type, :assignee_count, :comment_count])
    |> Ash.Query.set_tenant(school.id)
    |> Ash.Query.sort([{:inserted_at, :desc}])
    |> Ash.read!(actor: actor)
  end

  defp load_actions(student, actor, school) do
    Action
    |> Ash.Query.filter(student_id == ^student.id and status == :pending)
    |> Ash.Query.set_tenant(school.id)
    |> Ash.Query.sort([{:due_on, :asc_nils_last}, {:inserted_at, :desc}])
    |> Ash.read!(actor: actor)
    |> Ash.load!([:assignee], authorize?: false)
  end

  defp has_completed_actions?(student, actor, school) do
    case Action
         |> Ash.Query.filter(student_id == ^student.id and status in [:completed, :cancelled])
         |> Ash.Query.set_tenant(school.id)
         |> Ash.count(actor: actor) do
      {:ok, n} -> n > 0
      _ -> false
    end
  end

  defp load_supports(student, actor, school) do
    SupportPlan
    |> Ash.Query.filter(student_id == ^student.id and status in [:offered, :in_progress])
    |> Ash.Query.set_tenant(school.id)
    |> Ash.Query.sort([{:starts_at, :desc_nils_last}, {:inserted_at, :desc}])
    |> Ash.read!(actor: actor)
    |> Ash.load!([:provider_staff], authorize?: false)
  end

  defp load_notes(student, actor, school) do
    Note
    |> Ash.Query.filter(student_id == ^student.id)
    |> Ash.Query.load([:edited?, :preview])
    |> Ash.Query.set_tenant(school.id)
    |> Ash.Query.sort([{:pinned?, :desc}, {:inserted_at, :desc}])
    |> Ash.read!(actor: actor)
    |> Ash.load!([:author], authorize?: false)
  end

  defp build_note_composer_form(student, actor, school) do
    Note
    |> AshPhoenix.Form.for_create(:create,
      actor: actor,
      tenant: school.id,
      domain: Intellispark.Support,
      as: "note",
      transform_params: fn _form, params, _ ->
        Map.put(params, "student_id", student.id)
      end
    )
    |> to_form()
  end

  defp load_recent_high_fives(student, actor, school) do
    HighFive
    |> Ash.Query.filter(student_id == ^student.id)
    |> Ash.Query.set_tenant(school.id)
    |> Ash.Query.sort([{:sent_at, :desc}])
    |> Ash.Query.limit(5)
    |> Ash.read!(actor: actor)
    |> Ash.load!([:sent_by], authorize?: false)
  end

  defp has_more_high_fives?(student, actor, school) do
    case HighFive
         |> Ash.Query.filter(student_id == ^student.id)
         |> Ash.Query.set_tenant(school.id)
         |> Ash.count(actor: actor) do
      {:ok, n} -> n > 5
      _ -> false
    end
  end

  defp load_templates(actor, school) do
    query =
      Intellispark.Recognition.HighFiveTemplate
      |> Ash.Query.filter(active? == true)

    Recognition.list_high_five_templates!(
      actor: actor,
      tenant: school.id,
      query: query
    )
  end

  defp load_survey_assignments(student, actor, school) do
    SurveyAssignment
    |> Ash.Query.filter(student_id == ^student.id)
    |> Ash.Query.set_tenant(school.id)
    |> Ash.Query.sort([{:assigned_at, :desc}])
    |> Ash.read!(actor: actor)
    |> Ash.load!([:assigned_by, :survey_template], authorize?: false)
  end

  defp load_survey_templates(actor, school) do
    query =
      Intellispark.Assessments.SurveyTemplate
      |> Ash.Query.filter(published? == true)

    Assessments.list_survey_templates!(
      actor: actor,
      tenant: school.id,
      query: query
    )
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

    note_versions =
      Note.Version
      |> Ash.Query.filter(student_id == ^student.id)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&Map.put(&1, :__kind__, :note_event))

    high_five_versions =
      HighFive.Version
      |> Ash.Query.filter(student_id == ^student.id)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&Map.put(&1, :__kind__, :recognition_event))

    survey_versions =
      SurveyAssignment.Version
      |> Ash.Query.filter(student_id == ^student.id)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&Map.put(&1, :__kind__, :survey_event))

    indicator_versions =
      Intellispark.Indicators.IndicatorScore.Version
      |> Ash.Query.filter(student_id == ^student.id)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&Map.put(&1, :__kind__, :indicator_event))

    team_versions =
      TeamMembership.Version
      |> Ash.Query.filter(student_id == ^student.id)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&Map.put(&1, :__kind__, :team_event))

    connection_versions =
      KeyConnection.Version
      |> Ash.Query.filter(student_id == ^student.id)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&Map.put(&1, :__kind__, :connection_event))

    strength_versions =
      Strength.Version
      |> Ash.Query.filter(student_id == ^student.id)
      |> Ash.Query.set_tenant(school.id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(&Map.put(&1, :__kind__, :strength_event))

    (student_versions ++
       tag_versions ++
       status_versions ++
       note_versions ++
       high_five_versions ++
       survey_versions ++
       indicator_versions ++
       team_versions ++
       connection_versions ++
       strength_versions)
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
        :open_supports_count,
        :recent_high_fives_count,
        tags: [:id, :name, :color],
        team_memberships: [:user, :added_by],
        key_connections: [:connected_user]
      ] ++ Intellispark.Indicators.Dimension.all(),
      actor: actor,
      tenant: school.id
    )
  end

  defp load_strengths_for(student, actor, school) do
    Intellispark.Teams.Strength
    |> Ash.Query.filter(student_id == ^student.id)
    |> Ash.Query.sort(:display_order)
    |> Ash.Query.set_tenant(school.id)
    |> Ash.read!(actor: actor)
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
            <.recent_high_fives_panel
              high_fives={@recent_high_fives}
              has_more?={@has_more_high_fives?}
              current_user={@current_user}
            />
            <.key_indicators_panel student={@student} />

            <.team_members_panel
              memberships={@student.team_memberships || []}
              student={@student}
            />

            <.notes_panel
              notes={@notes}
              composer_form={@note_composer_form}
              current_user={@current_user}
              edit_note_id={@edit_note_id}
            />
            <.forms_surveys_panel assignments={@survey_assignments} />
          </div>

          <div class="space-y-md">
            <.profile_card student={@student} />

            <.strengths_panel strengths={@strengths} />

            <.key_connections_panel connections={@student.key_connections || []} />

            <.flags_panel flags={@flags} />

            <.actions_panel actions={@actions} has_completed?={@has_completed_actions?} />

            <.supports_panel supports={@supports} />

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

      <.live_component
        :if={@new_action_open?}
        module={IntellisparkWeb.StudentLive.NewActionModal}
        id="new-action-modal"
        student={@student}
        actor={@current_user}
        staff={@staff}
        error_message={nil}
      />

      <.live_component
        :if={@new_support_open?}
        module={IntellisparkWeb.StudentLive.NewSupportModal}
        id="new-support-modal"
        student={@student}
        actor={@current_user}
        staff={@staff}
      />

      <.live_component
        :if={@support_detail_open? and @active_support_id}
        module={IntellisparkWeb.StudentLive.SupportDetailSheet}
        id={"support-sheet-#{@active_support_id}"}
        support_id={@active_support_id}
        actor={@current_user}
        tenant={@current_school.id}
      />

      <.live_component
        :if={@new_high_five_open?}
        module={IntellisparkWeb.StudentLive.NewHighFiveModal}
        id="new-high-five-modal"
        student={@student}
        actor={@current_user}
        templates={@templates}
        error_message={nil}
      />

      <.live_component
        :if={@previous_high_fives_open?}
        module={IntellisparkWeb.StudentLive.PreviousHighFivesDrawer}
        id="previous-high-fives-drawer"
        student={@student}
        actor={@current_user}
        tenant={@current_school.id}
      />

      <.live_component
        :if={@new_survey_open?}
        module={IntellisparkWeb.StudentLive.NewSurveyModal}
        id="new-survey-modal"
        student={@student}
        actor={@current_user}
        templates={@survey_templates}
      />

      <.live_component
        :if={@new_team_member_open?}
        module={IntellisparkWeb.StudentLive.NewTeamMemberModal}
        id="new-team-member-modal"
        student={@student}
        actor={@current_user}
        staff={@staff}
      />

      <.live_component
        :if={@new_connection_open?}
        module={IntellisparkWeb.StudentLive.NewConnectionModal}
        id="new-connection-modal"
        student={@student}
        actor={@current_user}
        staff={@staff}
      />

      <.live_component
        :if={@new_strength_open?}
        module={IntellisparkWeb.StudentLive.NewStrengthModal}
        id="new-strength-modal"
        student={@student}
        actor={@current_user}
      />
    </Layouts.app>
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
  defp icon_for(:note_event), do: "hero-document-text"
  defp icon_for(:recognition_event), do: "hero-hand-raised"
  defp icon_for(:survey_event), do: "hero-clipboard-document"
  defp icon_for(:indicator_event), do: "hero-chart-bar"
  defp icon_for(:team_event), do: "hero-user-plus"
  defp icon_for(:connection_event), do: "hero-user-circle"
  defp icon_for(:strength_event), do: "hero-sparkles"

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

  defp summarise(%{__kind__: :note_event, version_action_name: :create}), do: "Posted a note"
  defp summarise(%{__kind__: :note_event, version_action_name: :update}), do: "Edited a note"
  defp summarise(%{__kind__: :note_event, version_action_name: :pin}), do: "Pinned a note"
  defp summarise(%{__kind__: :note_event, version_action_name: :unpin}), do: "Unpinned a note"
  defp summarise(%{__kind__: :note_event, version_action_name: :destroy}), do: "Note removed"
  defp summarise(%{__kind__: :note_event}), do: "Note change"

  defp summarise(%{__kind__: :recognition_event, version_action_name: :send_to_student}),
    do: "Sent a High 5"

  defp summarise(%{__kind__: :recognition_event, version_action_name: :record_view}),
    do: "High 5 viewed"

  defp summarise(%{__kind__: :recognition_event, version_action_name: :destroy}),
    do: "High 5 removed"

  defp summarise(%{__kind__: :recognition_event}), do: "High 5 update"

  defp summarise(%{__kind__: :survey_event, version_action_name: :assign_to_student}),
    do: "Survey assigned"

  defp summarise(%{__kind__: :survey_event, version_action_name: :bulk_assign_to_students}),
    do: "Survey assigned"

  defp summarise(%{__kind__: :survey_event, version_action_name: :submit}),
    do: "Survey submitted"

  defp summarise(%{__kind__: :survey_event, version_action_name: :expire}),
    do: "Survey expired"

  defp summarise(%{__kind__: :survey_event}), do: "Survey progress"

  defp summarise(%{__kind__: :indicator_event, version_action_name: :create}),
    do: "Indicators computed"

  defp summarise(%{__kind__: :indicator_event, version_action_name: :update}),
    do: "Indicators refreshed"

  defp summarise(%{__kind__: :indicator_event}), do: "Indicator update"

  defp summarise(%{__kind__: :team_event, version_action_name: :create}),
    do: "Team member added"

  defp summarise(%{__kind__: :team_event, version_action_name: :update}),
    do: "Team member updated"

  defp summarise(%{__kind__: :team_event, version_action_name: :destroy}),
    do: "Team member removed"

  defp summarise(%{__kind__: :team_event}), do: "Team change"

  defp summarise(%{__kind__: :connection_event, version_action_name: :create}),
    do: "Key connection added"

  defp summarise(%{__kind__: :connection_event, version_action_name: :update}),
    do: "Key connection updated"

  defp summarise(%{__kind__: :connection_event, version_action_name: :destroy}),
    do: "Key connection removed"

  defp summarise(%{__kind__: :connection_event}), do: "Key connection change"

  defp summarise(%{__kind__: :strength_event, version_action_name: :create}),
    do: "Strength added"

  defp summarise(%{__kind__: :strength_event, version_action_name: :update}),
    do: "Strength edited"

  defp summarise(%{__kind__: :strength_event, version_action_name: :destroy}),
    do: "Strength removed"

  defp summarise(%{__kind__: :strength_event}), do: "Strength change"

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
            <.count_badge value={@student.recent_high_fives_count} variant={:high_fives} />
            <span class="text-azure text-xs">High-5s</span>
          </div>
          <div class="flex items-center gap-sm">
            <.count_badge value={@student.open_flags_count} variant={:flags} />
            <span class="text-azure text-xs">Flags</span>
          </div>
          <div class="flex items-center gap-sm">
            <.count_badge value={@student.open_supports_count} variant={:supports} />
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

  attr :actions, :list, required: true
  attr :has_completed?, :boolean, required: true

  defp actions_panel(assigns) do
    ~H"""
    <div class="bg-white rounded-card shadow-card p-md space-y-sm">
      <div class="flex items-center justify-between">
        <h2 class="text-sm font-semibold text-abbey">
          Action needed ({length(@actions)})
        </h2>
        <button
          type="button"
          phx-click="open_new_action_modal"
          class="text-xs text-brand underline hover:text-brand-700"
        >
          + Action
        </button>
      </div>

      <ul :if={@actions != []} class="space-y-xs">
        <li
          :for={action <- @actions}
          id={"action-#{action.id}"}
          class="flex items-start gap-xs p-xs rounded hover:bg-whitesmoke"
        >
          <input
            type="checkbox"
            phx-click="complete_action"
            phx-value-id={action.id}
            disabled={action.status != :pending}
            class="mt-0.5"
          />
          <div class="flex-1 min-w-0 space-y-0.5">
            <p class="text-sm text-abbey">
              <strong>{action.assignee.email}</strong> has been asked to {action.description}
            </p>
            <p
              :if={action.due_on}
              class="text-xs text-chocolate flex items-center gap-0.5"
            >
              <span class="hero-calendar-days size-3"></span>
              Due {Calendar.strftime(action.due_on, "%b %-d, %Y")}
            </p>
          </div>
        </li>
      </ul>

      <.empty_state
        :if={@actions == []}
        icon="hero-clipboard-document-check"
        message="No open actions for this student."
      />

      <p :if={@has_completed?} class="pt-xs border-t border-abbey/10">
        <button
          type="button"
          phx-click="open_completed_actions"
          class="text-xs text-brand underline"
        >
          View completed actions
        </button>
      </p>
    </div>
    """
  end

  attr :supports, :list, required: true

  defp supports_panel(assigns) do
    ~H"""
    <div class="bg-white rounded-card shadow-card p-md space-y-sm">
      <div class="flex items-center justify-between">
        <h2 class="text-sm font-semibold text-abbey">
          Supports ({length(@supports)})
        </h2>
        <button
          type="button"
          phx-click="open_new_support_modal"
          class="text-xs text-brand underline hover:text-brand-700"
        >
          + Support
        </button>
      </div>

      <ol :if={@supports != []} class="space-y-sm">
        <li
          :for={s <- @supports}
          id={"support-#{s.id}"}
          phx-click="open_support_sheet"
          phx-value-id={s.id}
          class="cursor-pointer p-xs rounded hover:bg-whitesmoke space-y-0.5"
        >
          <div class="flex items-start justify-between gap-sm">
            <p class="text-sm font-medium text-abbey">{s.title}</p>
            <.support_status_pill status={s.status} />
          </div>
          <p
            :if={s.starts_at || s.ends_at}
            class="text-xs text-azure flex items-center gap-0.5"
          >
            <span class="hero-calendar size-3"></span>
            {format_date_range(s.starts_at, s.ends_at)}
          </p>
          <p :if={s.description} class="text-xs text-abbey line-clamp-2">{s.description}</p>
        </li>
      </ol>

      <.empty_state
        :if={@supports == []}
        icon="hero-heart"
        message="No supports in progress."
      />
    </div>
    """
  end

  attr :status, :atom, required: true

  defp support_status_pill(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-pill border px-2 py-0.5 text-[0.6875rem] font-medium",
      support_pill_classes(@status)
    ]}>
      {support_status_label(@status)}
    </span>
    """
  end

  defp support_pill_classes(:offered), do: "border-abbey/30 text-abbey bg-white"
  defp support_pill_classes(:in_progress), do: "border-brand text-brand bg-brand/5"

  defp support_pill_classes(:completed),
    do: "border-status-resolved-border text-status-resolved-text bg-white"

  defp support_pill_classes(:declined), do: "border-chocolate text-chocolate bg-chocolate/5"

  defp support_status_label(:offered), do: "Offered"
  defp support_status_label(:in_progress), do: "In progress"
  defp support_status_label(:completed), do: "Completed"
  defp support_status_label(:declined), do: "Declined"

  defp format_date_range(nil, nil), do: "No date assigned"
  defp format_date_range(start, nil), do: "Starts #{Calendar.strftime(start, "%b %-d, %Y")}"
  defp format_date_range(nil, fin), do: "Ends #{Calendar.strftime(fin, "%b %-d, %Y")}"

  defp format_date_range(s, f),
    do: "#{Calendar.strftime(s, "%b %-d, %Y")} – #{Calendar.strftime(f, "%b %-d, %Y")}"

  attr :notes, :list, required: true
  attr :composer_form, :any, required: true
  attr :current_user, :map, required: true
  attr :edit_note_id, :any, required: true

  defp notes_panel(assigns) do
    ~H"""
    <div class="bg-white rounded-card shadow-card p-md space-y-md">
      <div class="flex items-center justify-between">
        <h2 class="text-sm font-semibold text-abbey">Notes</h2>
      </div>

      <.form for={@composer_form} phx-change="validate_note" phx-submit="save_note">
        <.input
          field={@composer_form[:body]}
          type="textarea"
          placeholder="Add a note…"
          rows="3"
        />
        <div class="flex items-center justify-between pt-xs">
          <.input field={@composer_form[:sensitive?]} type="checkbox" label="Sensitive" />
          <.button type="submit" variant={:primary}>Post note</.button>
        </div>
      </.form>

      <div :if={@notes != []} class="space-y-sm">
        <.note_card
          :for={note <- Enum.filter(@notes, & &1.pinned?)}
          note={note}
          current_user={@current_user}
          editing?={@edit_note_id == note.id}
        />
        <.note_card
          :for={note <- Enum.reject(@notes, & &1.pinned?)}
          note={note}
          current_user={@current_user}
          editing?={@edit_note_id == note.id}
        />
      </div>

      <.empty_state
        :if={@notes == []}
        icon="hero-document-text"
        message="No notes for this student yet."
      />
    </div>
    """
  end

  attr :note, :map, required: true
  attr :current_user, :map, required: true
  attr :editing?, :boolean, required: true

  defp note_card(assigns) do
    ~H"""
    <article
      id={"note-#{@note.id}"}
      class={[
        "rounded-card p-sm space-y-0.5",
        @note.pinned? && "bg-chocolate/5 border border-chocolate/20",
        !@note.pinned? && "bg-whitesmoke"
      ]}
    >
      <div class="flex items-center justify-between text-xs">
        <div class="flex items-center gap-xs">
          <strong class="text-abbey">{@note.author.email}</strong>
          <span class="text-azure">· {relative_time(@note.inserted_at)}</span>
          <span :if={@note.edited?} class="text-azure italic">· edited</span>
          <span :if={@note.sensitive?} class="text-chocolate font-medium">· sensitive</span>
        </div>
        <div class="flex items-center gap-xs">
          <button
            type="button"
            phx-click={if @note.pinned?, do: "unpin_note", else: "pin_note"}
            phx-value-id={@note.id}
            title={if @note.pinned?, do: "Unpin", else: "Pin"}
            aria-label={if @note.pinned?, do: "Unpin note", else: "Pin note"}
          >
            <span class={
              if @note.pinned?,
                do: "hero-bookmark-solid size-3.5 text-chocolate",
                else: "hero-bookmark size-3.5 text-azure"
            }>
            </span>
          </button>
          <button
            :if={@note.author_id == @current_user.id and not @editing?}
            type="button"
            phx-click="edit_note"
            phx-value-id={@note.id}
            class="text-xs text-brand underline"
          >
            Edit
          </button>
        </div>
      </div>

      <div :if={@editing?} class="pt-xs">
        <form
          phx-submit="save_edit_note"
          phx-value-id={@note.id}
          class="space-y-xs"
        >
          <textarea
            name="body"
            rows="3"
            class="w-full rounded border border-abbey/20 p-xs text-sm"
          ><%= @note.body %></textarea>
          <div class="flex justify-end gap-xs">
            <.button type="button" variant={:ghost} phx-click="cancel_edit_note">
              Cancel
            </.button>
            <.button type="submit" variant={:primary}>Save</.button>
          </div>
        </form>
      </div>

      <p :if={not @editing?} class="text-sm text-abbey whitespace-pre-line">
        {@note.body}
      </p>
    </article>
    """
  end

  attr :high_fives, :list, required: true
  attr :has_more?, :boolean, required: true
  attr :current_user, :map, required: true

  defp recent_high_fives_panel(assigns) do
    ~H"""
    <div class="bg-white rounded-card shadow-card p-md space-y-sm">
      <div class="flex items-center justify-between">
        <h2 class="text-sm font-semibold text-abbey">Recent High 5's</h2>
        <button
          type="button"
          phx-click="open_new_high_five_modal"
          class="text-xs text-brand underline hover:text-brand-700"
        >
          + High 5
        </button>
      </div>

      <ul :if={@high_fives != []} class="space-y-sm">
        <li
          :for={h <- @high_fives}
          id={"high-five-#{h.id}"}
          class="rounded-card p-sm bg-status-resolved border border-status-resolved-border/40 space-y-0.5"
        >
          <p class="text-sm font-semibold text-abbey">{h.title}</p>
          <p class="text-sm text-abbey whitespace-pre-line">{h.body}</p>
          <p class="text-xs text-azure pt-xs">
            Sent by <strong>{h.sent_by.email}</strong>
            · {relative_time(h.sent_at)} · viewed {h.view_count} time<span :if={h.view_count != 1}>s</span>
          </p>
        </li>
      </ul>

      <.empty_state
        :if={@high_fives == []}
        icon="hero-hand-raised"
        message="No High 5's yet — send the first one!"
      />

      <p :if={@has_more?} class="pt-xs text-right">
        <button
          type="button"
          phx-click="open_previous_high_fives"
          class="text-xs text-brand underline"
        >
          View previous High 5's
        </button>
      </p>
    </div>
    """
  end

  attr :assignments, :list, required: true

  defp forms_surveys_panel(assigns) do
    ~H"""
    <div class="bg-white rounded-card shadow-card p-md space-y-sm">
      <div class="flex items-center justify-between">
        <h2 class="text-sm font-semibold text-abbey">
          Forms &amp; Surveys ({length(@assignments)})
        </h2>
        <button
          type="button"
          phx-click="open_new_survey_modal"
          class="text-xs text-brand underline hover:text-brand-700"
        >
          + Form assignment
        </button>
      </div>

      <ul :if={@assignments != []} class="space-y-xs">
        <li
          :for={a <- @assignments}
          id={"assignment-#{a.id}"}
          class="flex items-center justify-between gap-sm p-xs rounded border border-abbey/10 bg-whitesmoke"
        >
          <div class="min-w-0 space-y-0.5">
            <p class="text-sm font-medium text-abbey truncate">
              {a.survey_template.name}
            </p>
            <p class="text-xs text-azure">
              Assigned by <strong>{a.assigned_by.email}</strong>
              on {Calendar.strftime(a.assigned_at, "%b %-d, %Y")}
            </p>
          </div>
          <.assignment_state_pill state={a.state} submitted_at={a.submitted_at} />
        </li>
      </ul>

      <.empty_state
        :if={@assignments == []}
        icon="hero-clipboard-document"
        message="No forms assigned yet."
      />
    </div>
    """
  end

  attr :state, :atom, required: true
  attr :submitted_at, :any, required: true

  defp assignment_state_pill(%{state: :submitted} = assigns) do
    ~H"""
    <span class="text-xs text-azure">
      Completed on {Calendar.strftime(@submitted_at, "%b %-d, %Y")}
    </span>
    """
  end

  defp assignment_state_pill(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-pill border px-2 py-0.5 text-[0.6875rem] font-medium",
      assignment_pill_classes(@state)
    ]}>
      {assignment_pill_label(@state)}
    </span>
    """
  end

  defp assignment_pill_classes(:assigned), do: "border-abbey/30 text-abbey bg-white"
  defp assignment_pill_classes(:in_progress), do: "border-brand text-brand bg-brand/5"

  defp assignment_pill_classes(:expired),
    do: "border-chocolate text-chocolate bg-chocolate/5"

  defp assignment_pill_label(:assigned), do: "Not started"
  defp assignment_pill_label(:in_progress), do: "In progress"
  defp assignment_pill_label(:expired), do: "Expired"

  attr :student, :map, required: true

  defp key_indicators_panel(assigns) do
    dimensions = Intellispark.Indicators.Dimension.all()
    half = div(length(dimensions) + 1, 2)
    {left, right} = Enum.split(dimensions, half)
    assigns = assign(assigns, left: left, right: right)

    ~H"""
    <div class="bg-white rounded-card shadow-card p-md space-y-sm">
      <h2 class="text-sm font-semibold text-abbey">
        Key SEL &amp; Well-Being Indicators
      </h2>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-x-md gap-y-xs">
        <div class="space-y-xs">
          <.indicator_row :for={dim <- @left} student={@student} dimension={dim} />
        </div>
        <div class="space-y-xs">
          <.indicator_row :for={dim <- @right} student={@student} dimension={dim} />
        </div>
      </div>
    </div>
    """
  end

  attr :student, :map, required: true
  attr :dimension, :atom, required: true

  defp indicator_row(assigns) do
    level = Map.get(assigns.student, assigns.dimension)
    assigns = assign(assigns, level: level)

    ~H"""
    <div class="flex items-center gap-sm">
      <.level_indicator :if={@level} level={@level} />
      <span
        :if={is_nil(@level)}
        class="inline-flex items-center rounded-pill border border-abbey/20 bg-whitesmoke px-2 py-0.5 text-[0.6875rem] font-medium text-azure"
      >
        —
      </span>
      <span class="text-sm text-abbey">
        {Intellispark.Indicators.Dimension.humanize(@dimension)}
      </span>
    </div>
    """
  end

  attr :memberships, :list, required: true
  attr :student, :map, required: true

  defp team_members_panel(assigns) do
    grouped = Enum.group_by(assigns.memberships, &team_group_key(&1.role))
    assigns = assign(assigns, grouped: grouped, count: length(assigns.memberships))

    ~H"""
    <div class="bg-white rounded-card shadow-card p-md space-y-md">
      <div class="flex items-center justify-between">
        <h2 class="text-sm font-semibold text-abbey">Team members ({@count})</h2>
        <button
          type="button"
          phx-click="open_new_team_member_modal"
          class="text-xs text-brand underline hover:text-brand-700"
        >
          + Team member
        </button>
      </div>

      <.role_group
        title="Current Teachers"
        empty="No course roster information added."
        memberships={@grouped[:teachers] || []}
      />
      <.role_group
        title="Family"
        empty="No family members added."
        memberships={@grouped[:family] || []}
      />
      <.role_group
        title="Other Staff"
        empty="No other staff added."
        memberships={@grouped[:other] || []}
      />
    </div>
    """
  end

  defp team_group_key(:teacher), do: :teachers
  defp team_group_key(:family), do: :family
  defp team_group_key(_), do: :other

  attr :title, :string, required: true
  attr :empty, :string, required: true
  attr :memberships, :list, required: true

  defp role_group(assigns) do
    ~H"""
    <div class="space-y-xs">
      <h3 class="text-xs uppercase text-azure tracking-wide">{@title}</h3>

      <p :if={@memberships == []} class="text-sm text-azure italic">{@empty}</p>

      <ul :if={@memberships != []} class="space-y-xs">
        <li :for={m <- @memberships} class="flex items-center gap-sm">
          <span class="inline-flex h-8 w-8 items-center justify-center rounded-full bg-brand-100 text-brand-700 text-xs font-medium">
            {user_initials(m.user)}
          </span>
          <div class="flex-1">
            <p class="text-sm text-abbey">
              {user_display_name(m.user)}
            </p>
            <p class="text-xs text-azure">{humanize_team_role(m.role)}</p>
          </div>
        </li>
      </ul>
    </div>
    """
  end

  defp user_display_name(%{first_name: first, last_name: last})
       when is_binary(first) and is_binary(last) and first != "" and last != "",
       do: "#{first} #{last}"

  defp user_display_name(%{email: email}) do
    case to_string_or_nil(email) do
      nil -> "Unknown"
      str -> str
    end
  end

  defp user_display_name(_), do: "Unknown"

  defp user_initials(%{first_name: first, last_name: last})
       when is_binary(first) and is_binary(last) and first != "" and last != "" do
    String.upcase(String.first(first)) <> String.upcase(String.first(last))
  end

  defp user_initials(%{email: email}) do
    case to_string_or_nil(email) do
      nil -> "?"
      str -> String.upcase(String.first(str))
    end
  end

  defp user_initials(_), do: "?"

  defp to_string_or_nil(nil), do: nil
  defp to_string_or_nil(""), do: nil
  defp to_string_or_nil(s) when is_binary(s), do: s
  defp to_string_or_nil(%Ash.CiString{} = s), do: Ash.CiString.value(s)
  defp to_string_or_nil(other), do: to_string(other)

  defp humanize_team_role(:teacher), do: "Teacher"
  defp humanize_team_role(:coach), do: "Coach"
  defp humanize_team_role(:counselor), do: "Counselor"
  defp humanize_team_role(:social_worker), do: "Social Worker"
  defp humanize_team_role(:clinician), do: "Clinician"
  defp humanize_team_role(:family), do: "Family member"
  defp humanize_team_role(:community_partner), do: "Community partner"
  defp humanize_team_role(:other), do: "Other"

  attr :connections, :list, required: true

  defp key_connections_panel(assigns) do
    ~H"""
    <div class="bg-white rounded-card shadow-card p-md space-y-sm">
      <div class="flex items-center justify-between">
        <h2 class="text-sm font-semibold text-abbey">
          Key connections ({length(@connections)})
        </h2>
        <button
          type="button"
          phx-click="open_new_connection_modal"
          class="text-xs text-brand underline hover:text-brand-700"
        >
          + Connection
        </button>
      </div>

      <p :if={@connections == []} class="text-sm text-azure italic">
        No connections added yet.
      </p>

      <ul :if={@connections != []} class="space-y-xs">
        <li :for={c <- @connections}>
          <p class="text-sm font-medium text-abbey">
            {user_display_name(c.connected_user)}
          </p>
          <p :if={c.note} class="text-xs text-azure italic">({c.note})</p>
        </li>
      </ul>
    </div>
    """
  end

  attr :strengths, :list, required: true

  defp strengths_panel(assigns) do
    ~H"""
    <div class="bg-white rounded-card shadow-card p-md space-y-sm">
      <div class="flex items-center justify-between">
        <h2 class="text-sm font-semibold text-abbey">Strengths</h2>
        <button
          type="button"
          phx-click="open_new_strength_modal"
          class="text-xs text-brand underline hover:text-brand-700"
        >
          + Strength
        </button>
      </div>

      <p :if={@strengths == []} class="text-sm text-azure italic">
        No strengths recorded yet.
      </p>

      <ul :if={@strengths != []} class="list-disc pl-lg space-y-xs text-sm text-abbey">
        <li :for={s <- @strengths}>{s.description}</li>
      </ul>
    </div>
    """
  end
end
