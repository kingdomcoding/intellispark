defmodule Intellispark.Accounts.SchoolInvitation.Changes.SendInvitationEmail do
  @moduledoc """
  After-action that loads `:school` + `:inviter` on a freshly-created invitation
  and hands it to `SendInvitation` for delivery.
  """

  use Ash.Resource.Change

  alias Intellispark.Accounts.SchoolInvitation.Senders.SendInvitation

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, invitation ->
      invitation = Ash.load!(invitation, [:school, :inviter], authorize?: false)
      SendInvitation.send(invitation)
      {:ok, invitation}
    end)
  end
end
