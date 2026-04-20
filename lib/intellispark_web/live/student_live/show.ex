defmodule IntellisparkWeb.StudentLive.Show do
  @moduledoc false
  use IntellisparkWeb, :live_view

  alias Intellispark.Students

  @impl true
  def mount(params, _session, socket) do
    %{current_user: actor, current_school: school} = socket.assigns
    id = params["id"]

    case Students.get_student(id, actor: actor, tenant: school.id) do
      {:ok, student} ->
        student = Ash.load!(student, [:display_name], actor: actor, tenant: school.id)

        {:ok,
         socket
         |> assign(
           page_title: to_string(student.display_name),
           student: student,
           breadcrumb: resolve_breadcrumb(params["return_to"], actor, school)
         )}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Student not found")
         |> redirect(to: ~p"/students")}
    end
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
