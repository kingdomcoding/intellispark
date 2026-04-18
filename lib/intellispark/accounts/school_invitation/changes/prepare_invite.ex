defmodule Intellispark.Accounts.SchoolInvitation.Changes.PrepareInvite do
  @moduledoc """
  Fills in the server-controlled fields on a `SchoolInvitation.invite` call:
  `inviter_id` from the actor, and a 7-day `expires_at` from the current time.
  """

  use Ash.Resource.Change

  @invite_lifetime_days 7

  @impl true
  def change(changeset, _opts, context) do
    actor = context.actor

    if is_nil(actor) do
      Ash.Changeset.add_error(changeset, field: :inviter_id, message: "actor is required")
    else
      expires_at = DateTime.add(DateTime.utc_now(), @invite_lifetime_days, :day)

      changeset
      |> Ash.Changeset.force_change_attribute(:inviter_id, actor.id)
      |> Ash.Changeset.force_change_attribute(:expires_at, expires_at)
    end
  end
end
