defmodule IntellisparkWeb.StudentLive.SettingsBulkModal do
  @moduledoc """
  Placeholder for future bulk-settings actions (archive, clear tags,
  reassign team). Phase 2 ships with a 'coming soon' message so the
  settings icon on the bulk toolbar has something to open.
  """

  use IntellisparkWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id={@id} on_cancel={JS.push("close_bulk_modal")} show>
        <:title>Bulk settings</:title>

        <p class="text-abbey">
          Bulk settings for {MapSet.size(@selected_ids)} selected student(s).
          Archive, clear tags, and reassign team land in later phases.
        </p>
      </.modal>
    </div>
    """
  end
end
