defmodule IntellisparkWeb.CustomListLive.Show do
  @moduledoc """
  /lists/:id — applies a CustomList's filter spec to Students and renders
  the same table as /students. Shares the filter bar + bulk toolbar.
  """

  use IntellisparkWeb, :live_view

  alias Intellispark.Students

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    %{current_user: actor, current_school: school} = socket.assigns

    with {:ok, list} <- Students.get_custom_list(id, actor: actor, tenant: school.id),
         {:ok, students} <- Students.run_custom_list(id, actor: actor, tenant: school.id) do
      students =
        Ash.load!(
          students,
          [
            :display_name,
            :current_status,
            :open_flags_count,
            :open_supports_count,
            :recent_high_fives_count,
            tags: [:id, :name, :color]
          ],
          actor: actor,
          tenant: school.id
        )

      {:ok,
       socket
       |> assign(
         page_title: list.name,
         list: list,
         students: students,
         selected: MapSet.new(),
         active_modal: nil
       )}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "List not found")
         |> redirect(to: ~p"/lists")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_school={@current_school}
      breadcrumb={%{label: "Back to my lists", path: ~p"/lists"}}
      onboarding_incomplete?={@onboarding_incomplete?}
    >
      <section class="container-lg py-xl space-y-md">
        <div class="flex items-center justify-between">
          <h1 class="text-display-md text-brand">{@list.name}</h1>
          <.link
            navigate={~p"/insights?list_id=#{@list.id}&return_to=#{~p"/lists/#{@list.id}"}"}
            class="text-sm text-brand hover:underline"
          >
            View insights →
          </.link>
        </div>
        <p :if={@list.description} class="text-azure">{@list.description}</p>

        <div class="bg-white rounded-card shadow-card overflow-hidden">
          <table class="w-full text-sm text-left text-abbey">
            <thead class="border-b border-abbey/10 text-xs uppercase tracking-wide text-azure">
              <tr>
                <th class="px-md py-sm">Student ({length(@students)})</th>
                <th class="px-md py-sm text-center">High-5s</th>
                <th class="px-md py-sm text-center">Flags</th>
                <th class="px-md py-sm text-center">Status</th>
                <th class="px-md py-sm text-center">Supports</th>
                <th class="px-md py-sm">Tags</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-abbey/10">
              <tr
                :for={s <- @students}
                phx-click={JS.navigate(~p"/students/#{s.id}?return_to=/lists/#{@list.id}")}
                class="hover:bg-whitesmoke/40 cursor-pointer"
              >
                <td class="px-md py-sm">
                  <.link
                    navigate={~p"/students/#{s.id}?return_to=/lists/#{@list.id}"}
                    class="text-brand hover:text-brand-700"
                  >
                    {s.display_name}
                  </.link>
                </td>
                <td class="px-md py-sm text-center">
                  <.count_badge value={s.recent_high_fives_count} variant={:high_fives} />
                </td>
                <td class="px-md py-sm text-center">
                  <.count_badge value={s.open_flags_count} variant={:flags} />
                </td>
                <td class="px-md py-sm text-center">
                  <.status_chip_for_status :if={s.current_status} status={s.current_status} />
                </td>
                <td class="px-md py-sm text-center">
                  <.count_badge value={s.open_supports_count} variant={:supports} />
                </td>
                <td class="px-md py-sm">
                  <.tag_chip_row tags={s.tags || []} max_visible={2} />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
