defmodule IntellisparkWeb.StudentLive.TagBulkModal do
  @moduledoc false

  use IntellisparkWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id={@id} on_cancel={JS.push("close_bulk_modal")} show>
        <:title>Apply tag to {MapSet.size(@selected_ids)} student(s)</:title>

        <div class="space-y-sm">
          <p class="text-abbey text-sm">Pick a tag to apply.</p>
          <ul class="max-h-64 overflow-y-auto divide-y divide-abbey/10">
            <li :for={tag <- @tags}>
              <button
                type="button"
                phx-click="apply_tag"
                phx-value-tag_id={tag.id}
                class="w-full flex items-center gap-sm px-sm py-sm hover:bg-whitesmoke text-left"
              >
                <span
                  class="inline-block size-3 rounded"
                  style={"background: #{tag.color}"}
                >
                </span>
                <span class="text-abbey">{tag.name}</span>
              </button>
            </li>
          </ul>
        </div>
      </.modal>
    </div>
    """
  end
end
