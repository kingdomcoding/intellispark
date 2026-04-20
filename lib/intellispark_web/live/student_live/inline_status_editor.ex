defmodule IntellisparkWeb.StudentLive.InlineStatusEditor do
  @moduledoc """
  Sidebar control for the Student Hub's status field. A plain <select>
  cycling through the school's statuses + a Clear button visible only
  when a current_status is set. Each change routes through
  Students.set_student_status/3 or Students.clear_student_status/2 so
  the StudentStatus ledger stays consistent.
  """

  use IntellisparkWeb, :live_component

  alias Intellispark.Students

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center gap-sm">
      <form phx-change="set_status" phx-target={@myself} class="flex-1">
        <select
          name="status_id"
          class="w-full rounded-pill border border-abbey/20 bg-white px-md py-1 text-sm"
        >
          <option value="">— No status —</option>
          <option
            :for={s <- @statuses}
            value={s.id}
            selected={@student.current_status_id == s.id}
          >
            {s.name}
          </option>
        </select>
      </form>
      <button
        :if={@student.current_status_id}
        type="button"
        phx-click="clear_status"
        phx-target={@myself}
        class="text-xs text-azure hover:text-abbey underline"
      >
        Clear
      </button>
    </div>
    """
  end

  @impl true
  def handle_event("set_status", %{"status_id" => ""}, socket), do: {:noreply, socket}

  def handle_event("set_status", %{"status_id" => id}, socket) do
    %{student: student, actor: actor} = socket.assigns

    {:ok, _student} =
      Students.set_student_status(student, id,
        actor: actor,
        tenant: student.school_id
      )

    send(self(), {__MODULE__, {:status_changed, student.id}})
    {:noreply, socket}
  end

  def handle_event("clear_status", _params, socket) do
    %{student: student, actor: actor} = socket.assigns

    {:ok, _student} =
      Students.clear_student_status(student,
        actor: actor,
        tenant: student.school_id
      )

    send(self(), {__MODULE__, {:status_changed, student.id}})
    {:noreply, socket}
  end
end
