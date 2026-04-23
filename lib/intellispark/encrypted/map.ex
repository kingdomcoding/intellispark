defmodule Intellispark.Encrypted.Map do
  @moduledoc """
  Ash type that JSON-encodes a map, encrypts via `Intellispark.Vault`,
  and stores as bytea. Used for IntegrationProvider.credentials and
  similar secret-bearing attributes. Read path decrypts + decodes.
  """

  use Ash.Type

  @impl Ash.Type
  def storage_type(_), do: :binary

  @impl Ash.Type
  def cast_input(nil, _), do: {:ok, nil}
  def cast_input(value, _) when is_map(value), do: {:ok, value}
  def cast_input(_, _), do: :error

  @impl Ash.Type
  def cast_stored(nil, _), do: {:ok, nil}

  def cast_stored(value, _) when is_binary(value) do
    with {:ok, decrypted} <- Intellispark.Vault.decrypt(value) do
      Jason.decode(decrypted)
    end
  end

  def cast_stored(_, _), do: :error

  @impl Ash.Type
  def dump_to_native(nil, _), do: {:ok, nil}

  def dump_to_native(value, _) when is_map(value) do
    with {:ok, encoded} <- Jason.encode(value) do
      Intellispark.Vault.encrypt(encoded)
    end
  end

  def dump_to_native(_, _), do: :error
end
