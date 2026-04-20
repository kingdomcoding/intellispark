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
  def handle_event("open_edit_modal", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({IntellisparkWeb.StudentLive.InlineTagEditor, {:tags_changed, id}}, socket)
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
            <.placeholder_card title="Profile" phase="Phase H" />
            <.placeholder_card title="Status" phase="Phase G" />
            <.placeholder_card title="Tags" phase="Phase F" />
          </div>
        </div>

        <.placeholder_card title="Activity" phase="Phase I" />
      </section>
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
