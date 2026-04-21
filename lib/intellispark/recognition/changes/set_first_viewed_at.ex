defmodule Intellispark.Recognition.Changes.SetFirstViewedAt do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case changeset.data.first_viewed_at do
      nil ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :first_viewed_at,
          DateTime.utc_now()
        )

      _ ->
        changeset
    end
  end
end
