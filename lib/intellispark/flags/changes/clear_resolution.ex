defmodule Intellispark.Flags.Changes.ClearResolution do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.force_change_attribute(changeset, :resolution_note, nil)
  end
end
