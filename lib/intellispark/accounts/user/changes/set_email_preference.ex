defmodule Intellispark.Accounts.User.Changes.SetEmailPreference do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _ctx) do
    kind = Ash.Changeset.get_argument(changeset, :event_kind)
    enabled? = Ash.Changeset.get_argument(changeset, :enabled?)

    current = Ash.Changeset.get_attribute(changeset, :email_preferences) || %{}
    next = Map.put(current, kind, enabled?)

    Ash.Changeset.force_change_attribute(changeset, :email_preferences, next)
  end
end
