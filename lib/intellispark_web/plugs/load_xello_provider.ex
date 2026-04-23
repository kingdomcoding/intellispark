defmodule IntellisparkWeb.Plugs.LoadXelloProvider do
  @moduledoc """
  Loads the `IntegrationProvider` referenced by `X-Xello-Provider-Id`
  header. Halts with 401 if missing or non-Xello. Assigns the loaded
  provider to `conn.assigns[:xello_provider]` on success.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    provider_id = get_req_header(conn, "x-xello-provider-id") |> List.first()

    case lookup(provider_id) do
      {:ok, provider} -> assign(conn, :xello_provider, provider)
      :error -> conn |> send_resp(401, "unknown provider") |> halt()
    end
  end

  defp lookup(nil), do: :error

  defp lookup(provider_id) do
    case Intellispark.Integrations.lookup_provider_for_webhook(provider_id, authorize?: false) do
      {:ok, %{provider_type: :xello} = provider} -> {:ok, provider}
      _ -> :error
    end
  end
end
