defmodule IntellisparkWeb.HealthController do
  use IntellisparkWeb, :controller

  alias Intellispark.Repo

  def check(conn, _params) do
    case Ecto.Adapters.SQL.query(Repo, "SELECT 1", []) do
      {:ok, _} -> send_resp(conn, 200, "ok")
      _ -> send_resp(conn, 503, "db unavailable")
    end
  end
end
