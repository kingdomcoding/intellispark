defmodule Intellispark.Recognition.Changes.IncrementViewCount do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    current = changeset.data.view_count || 0
    Ash.Changeset.force_change_attribute(changeset, :view_count, current + 1)
  end
end
