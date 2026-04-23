defmodule IntellisparkWeb.Plugs.CacheRawBody do
  @moduledoc """
  Body reader that caches the raw request body on
  `conn.assigns[:raw_body]` so webhook HMAC verifiers can read the
  bytes unaltered after `Plug.Parsers` has consumed the stream.
  """

  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        cached = conn.assigns[:raw_body] || []
        {:ok, body, Plug.Conn.assign(conn, :raw_body, [body | cached])}

      {:more, body, conn} ->
        cached = conn.assigns[:raw_body] || []
        {:more, body, Plug.Conn.assign(conn, :raw_body, [body | cached])}

      other ->
        other
    end
  end
end
