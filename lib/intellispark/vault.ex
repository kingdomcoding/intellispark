defmodule Intellispark.Vault do
  @moduledoc """
  Cloak vault — symmetric AES-GCM at rest. Key is loaded from
  `CLOAK_KEY` env (base64-encoded 32 bytes) in prod; dev/test fall
  back to a fixture key in config. Used via `Intellispark.Encrypted.Map`
  on attribute declarations that hold secrets (e.g., IntegrationProvider
  credentials).
  """

  use Cloak.Vault, otp_app: :intellispark

  @impl GenServer
  def init(config) do
    config =
      Keyword.put(config, :ciphers,
        default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: resolve_key()}
      )

    {:ok, config}
  end

  defp resolve_key do
    case System.get_env("CLOAK_KEY") do
      nil -> Application.fetch_env!(:intellispark, :cloak_key_fallback)
      base64 -> Base.decode64!(base64)
    end
  end
end
