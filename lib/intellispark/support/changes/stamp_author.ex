defmodule Intellispark.Support.Changes.StampAuthor do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    case context.actor do
      %{id: id} -> Ash.Changeset.force_change_attribute(changeset, :author_id, id)
      _ -> changeset
    end
  end
end
