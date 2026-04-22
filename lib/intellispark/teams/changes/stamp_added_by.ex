defmodule Intellispark.Teams.Changes.StampAddedBy do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    case context.actor do
      nil ->
        changeset

      actor ->
        Ash.Changeset.force_change_attribute(changeset, :added_by_id, actor.id)
    end
  end
end
