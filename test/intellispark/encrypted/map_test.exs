defmodule Intellispark.Encrypted.MapTest do
  use ExUnit.Case, async: false

  alias Intellispark.Encrypted.Map, as: EncryptedMap

  test "encrypt + dump_to_native + cast_stored round-trips" do
    value = %{"api_key" => "sk_abc123", "webhook_secret" => "whs_def456"}
    {:ok, encrypted} = EncryptedMap.dump_to_native(value, [])
    assert is_binary(encrypted)
    refute String.contains?(encrypted, "sk_abc123")

    {:ok, decoded} = EncryptedMap.cast_stored(encrypted, [])
    assert decoded == value
  end

  test "two encryptions produce different ciphertexts (random IV)" do
    value = %{"secret" => "same"}
    {:ok, a} = EncryptedMap.dump_to_native(value, [])
    {:ok, b} = EncryptedMap.dump_to_native(value, [])
    refute a == b
  end

  test "nil round-trips" do
    assert {:ok, nil} = EncryptedMap.dump_to_native(nil, [])
    assert {:ok, nil} = EncryptedMap.cast_stored(nil, [])
  end
end
