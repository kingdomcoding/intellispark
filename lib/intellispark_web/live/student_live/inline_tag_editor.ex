defmodule IntellisparkWeb.StudentLive.InlineTagEditor do
  @moduledoc """
  Per-student tag editor used on the /students/:id header card. Renders
  the existing tag chips with an × remover and a `+ Add tag` dropdown
  that lists the school's tags the student doesn't already have. Each
  add/remove roundtrips through Students.apply_tag_to_students/2 or
  Students.remove_tag_from_student/3 and notifies the parent LiveView
  via send/2 so the outer view can reload the full Student.
  """

  use IntellisparkWeb, :live_component

  alias Intellispark.Students

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign_new(:open?, fn -> false end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center gap-xs flex-wrap">
      <.tag_chip
        :for={tag <- @student.tags || []}
        label={tag.name}
        removable
        on_remove={JS.push("remove_tag", target: @myself)}
        value={tag.id}
      />

      <div class="relative">
        <button
          type="button"
          phx-click="toggle_dropdown"
          phx-target={@myself}
          class="cursor-pointer text-xs text-brand underline"
        >
          + Add tag
        </button>

        <div
          :if={@open?}
          phx-click-away="close_dropdown"
          phx-target={@myself}
          class="absolute left-0 mt-1 w-56 bg-white shadow-elevated rounded-card py-1 z-10"
        >
          <ul :if={unpicked(@student, @tags) != []}>
            <li :for={tag <- unpicked(@student, @tags)}>
              <button
                type="button"
                phx-click="add_tag"
                phx-value-tag_id={tag.id}
                phx-target={@myself}
                class="w-full flex items-center gap-xs px-sm py-xs hover:bg-whitesmoke text-left text-sm"
              >
                <span class="inline-block size-3 rounded" style={"background: #{tag.color}"}></span>
                {tag.name}
              </button>
            </li>
          </ul>
          <p
            :if={unpicked(@student, @tags) == []}
            class="px-sm py-xs text-sm text-azure italic"
          >
            All tags applied.
          </p>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_dropdown", _params, socket) do
    {:noreply, update(socket, :open?, &(!&1))}
  end

  def handle_event("close_dropdown", _params, socket) do
    {:noreply, assign(socket, open?: false)}
  end

  def handle_event("add_tag", %{"tag_id" => tag_id}, socket) do
    %{student: student, actor: actor} = socket.assigns

    {:ok, _tag} =
      Students.apply_tag_to_students(tag_id, [student.id],
        actor: actor,
        tenant: student.school_id
      )

    send(self(), {__MODULE__, {:tags_changed, student.id}})
    {:noreply, assign(socket, open?: false)}
  end

  def handle_event("remove_tag", %{"id" => tag_id}, socket) do
    %{student: student, actor: actor} = socket.assigns

    {:ok, _student} =
      Students.remove_tag_from_student(student, tag_id,
        actor: actor,
        tenant: student.school_id
      )

    send(self(), {__MODULE__, {:tags_changed, student.id}})
    {:noreply, socket}
  end

  defp unpicked(student, all_tags) do
    picked = MapSet.new(Enum.map(student.tags || [], & &1.id))
    Enum.reject(all_tags, &MapSet.member?(picked, &1.id))
  end
end
