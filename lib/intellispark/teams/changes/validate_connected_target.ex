defmodule Intellispark.Teams.Changes.ValidateConnectedTarget do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    user_id = Ash.Changeset.get_attribute(changeset, :connected_user_id)

    external_id =
      Ash.Changeset.get_attribute(changeset, :connected_external_person_id)

    case {user_id, external_id} do
      {nil, nil} ->
        Ash.Changeset.add_error(changeset,
          field: :connected_user_id,
          message: "must set either connected_user_id or connected_external_person_id"
        )

      {a, b} when not is_nil(a) and not is_nil(b) ->
        Ash.Changeset.add_error(changeset,
          field: :connected_user_id,
          message: "exactly one of connected_user_id or connected_external_person_id is allowed"
        )

      _ ->
        changeset
    end
  end
end
