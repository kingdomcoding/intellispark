defmodule IntellisparkWeb.CustomListLive.Index do
  @moduledoc """
  /lists — card grid of user's + shared CustomLists plus a built-in
  'All Students' card that links to /students. Each user-owned card
  has a ⋯ menu with Rename / Edit filters / Delete.
  """

  use IntellisparkWeb, :live_view

  alias Intellispark.Students
  alias IntellisparkWeb.CustomListLive.Composer

  @impl true
  def mount(_params, _session, socket) do
    %{current_user: actor, current_school: school} = socket.assigns
    lists = Students.list_custom_lists!(actor: actor, tenant: school.id)

    {:ok,
     socket
     |> assign(page_title: "My Lists", lists: lists, renaming_id: nil)}
  end

  @impl true
  def handle_event("open_rename", %{"id" => id}, socket) do
    {:noreply, assign(socket, renaming_id: id)}
  end

  def handle_event("close_composer", _params, socket) do
    {:noreply, assign(socket, renaming_id: nil)}
  end

  def handle_event("delete_list", %{"id" => id}, socket) do
    %{current_user: actor, current_school: school} = socket.assigns

    with {:ok, list} <- Students.get_custom_list(id, actor: actor, tenant: school.id),
         :ok <- Students.archive_custom_list(list, actor: actor, tenant: school.id) do
      {:noreply,
       socket
       |> put_flash(:info, "List deleted.")
       |> reload_lists()}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Could not delete the list.")}
    end
  end

  @impl true
  def handle_info({Composer, {:saved, :update, _list}}, socket) do
    {:noreply,
     socket
     |> assign(renaming_id: nil)
     |> put_flash(:info, "List updated.")
     |> reload_lists()}
  end

  def handle_info(_other, socket), do: {:noreply, socket}

  defp reload_lists(socket) do
    %{current_user: actor, current_school: school} = socket.assigns
    lists = Students.list_custom_lists!(actor: actor, tenant: school.id)
    assign(socket, lists: lists)
  end

  defp find_list(lists, id), do: Enum.find(lists, &(&1.id == id))

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
            list={nil}
          />

          <.list_card
            :for={list <- @lists}
            name={list.name}
            description={list.description || ""}
            path={~p"/lists/#{list.id}"}
            shared={list.shared?}
            list={list}
          />
        </div>

        <.live_component
          :if={@renaming_id}
          module={IntellisparkWeb.CustomListLive.Composer}
          id="rename-list-composer"
          mode={:update}
          actor={@current_user}
          current_school={@current_school}
          filter_spec={nil}
          list={find_list(@lists, @renaming_id)}
        />
      </section>
    </Layouts.app>
    """
  end

  attr :name, :string, required: true
  attr :description, :string, required: true
  attr :path, :string, required: true
  attr :shared, :boolean, default: false
  attr :list, :any, default: nil

  defp list_card(assigns) do
    ~H"""
    <div class="relative bg-white rounded-card shadow-card hover:shadow-elevated transition-shadow">
      <div :if={@list} class="absolute top-sm right-sm">
        <button
          type="button"
          phx-click={JS.toggle(to: "#list-menu-#{@list.id}")}
          class="text-azure hover:text-abbey p-xs"
          aria-label="List options"
        >
          <span class="hero-ellipsis-horizontal"></span>
        </button>

        <div
          id={"list-menu-#{@list.id}"}
          class="hidden absolute right-0 top-full mt-xs w-48 rounded-card bg-white shadow-elevated z-10 py-xs"
          phx-click-away={JS.hide(to: "#list-menu-#{@list.id}")}
        >
          <button
            type="button"
            phx-click="open_rename"
            phx-value-id={@list.id}
            class="block w-full text-left px-md py-sm text-sm hover:bg-whitesmoke"
          >
            Rename
          </button>
          <.link
            navigate={~p"/students?from_list=#{@list.id}"}
            class="block px-md py-sm text-sm hover:bg-whitesmoke"
          >
            Edit filters
          </.link>
          <button
            type="button"
            phx-click="delete_list"
            phx-value-id={@list.id}
            data-confirm="Delete this list? This can't be undone from the UI."
            class="block w-full text-left px-md py-sm text-sm text-chocolate hover:bg-whitesmoke"
          >
            Delete
          </button>
        </div>
      </div>

      <.link navigate={@path} class="block p-md">
        <div class="flex items-start justify-between pr-lg">
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
      </.link>
    </div>
    """
  end
end
