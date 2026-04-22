defmodule Intellispark.Flags.Changes.MaybeSetFollowup do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _ctx) do
    case Ash.Changeset.get_argument(changeset, :followup_at) do
      nil -> changeset
      %Date{} = date -> Ash.Changeset.force_change_attribute(changeset, :followup_at, date)
      _ -> changeset
    end
  end
end
