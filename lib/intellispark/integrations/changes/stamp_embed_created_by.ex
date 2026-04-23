defmodule Intellispark.Integrations.Changes.StampEmbedCreatedBy do
  @moduledoc """
  Stamps `created_by_id` from the actor on new `EmbedToken` rows.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    case context.actor do
      %{id: id} -> Ash.Changeset.force_change_attribute(changeset, :created_by_id, id)
      _ -> changeset
    end
  end
end
