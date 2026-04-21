defmodule Intellispark.Assessments.Changes.GenerateAccessToken do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    token =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    Ash.Changeset.force_change_attribute(changeset, :token, token)
  end
end
