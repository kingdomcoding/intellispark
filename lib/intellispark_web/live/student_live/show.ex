defmodule IntellisparkWeb.StudentLive.Show do
  @moduledoc false
  use IntellisparkWeb, :live_view

  alias Intellispark.Students

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    %{current_user: actor, current_school: school} = socket.assigns

    case Students.get_student(id, actor: actor, tenant: school.id) do
      {:ok, student} ->
        student = Ash.load!(student, [:display_name], actor: actor, tenant: school.id)

        {:ok,
         socket
         |> assign(page_title: to_string(student.display_name), student: student)}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Student not found")
         |> redirect(to: ~p"/students")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_school={@current_school}
      breadcrumb={%{label: "Back to All Students", path: ~p"/students"}}
    >
      <section class="container-lg py-xl space-y-md">
        <h1 class="text-display-md text-brand">{@student.display_name}</h1>
        <p class="text-azure">
          Student Hub content arrives in Phase 3. For now, the row click
          routes here so navigation doesn't 404.
        </p>
      </section>
    </Layouts.app>
    """
  end
end
