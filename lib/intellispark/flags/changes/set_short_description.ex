defmodule Intellispark.Flags.Changes.SetShortDescription do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    desc = Ash.Changeset.get_attribute(changeset, :description) || ""
    Ash.Changeset.force_change_attribute(changeset, :short_description, String.slice(desc, 0, 80))
  end
end
