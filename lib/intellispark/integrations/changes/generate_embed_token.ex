defmodule Intellispark.Integrations.Changes.GenerateEmbedToken do
  @moduledoc """
  Generates a 43-char URL-safe base64 token for a new or regenerated
  `EmbedToken`. 32 bytes of crypto-strong randomness.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    Ash.Changeset.force_change_attribute(changeset, :token, token)
  end
end
