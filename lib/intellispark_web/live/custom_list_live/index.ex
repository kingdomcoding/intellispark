defmodule IntellisparkWeb.CustomListLive.Index do
  @moduledoc """
  /lists — card grid of user's + shared CustomLists plus a built-in
  'All Students' card that links to /students.
  """

  use IntellisparkWeb, :live_view

  alias Intellispark.Students

  @impl true
  def mount(_params, _session, socket) do
    %{current_user: actor, current_school: school} = socket.assigns
    lists = Students.list_custom_lists!(actor: actor, tenant: school.id)

    {:ok, assign(socket, page_title: "My Lists", lists: lists)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_school={@current_school}>
      <section class="container-lg py-xl space-y-md">
        <header class="flex items-center justify-between">
          <h1 class="text-display-md text-brand">My Lists</h1>
        </header>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-md">
          <.list_card
            name="All Students"
            description="Every student in your school."
            path={~p"/students"}
            shared={true}
          />

          <.list_card
            :for={list <- @lists}
            name={list.name}
            description={list.description || ""}
            path={~p"/lists/#{list.id}"}
            shared={list.shared?}
          />
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :name, :string, required: true
  attr :description, :string, required: true
  attr :path, :string, required: true
  attr :shared, :boolean, default: false

  defp list_card(assigns) do
    ~H"""
    <.link navigate={@path} class="block">
      <div class="bg-white rounded-card shadow-card p-md hover:shadow-elevated transition-shadow">
        <div class="flex items-start justify-between">
          <h2 class="text-lg font-semibold text-abbey">{@name}</h2>
          <span
            :if={@shared}
            class="text-xs text-azure bg-whitesmoke px-2 py-0.5 rounded"
          >
            Shared
          </span>
        </div>
        <p :if={@description != ""} class="text-sm text-azure mt-sm">{@description}</p>
        <div class="mt-md">
          <span class="text-brand text-sm font-medium">Run →</span>
        </div>
      </div>
    </.link>
    """
  end
end
