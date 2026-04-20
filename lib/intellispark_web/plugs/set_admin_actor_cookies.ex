defmodule IntellisparkWeb.Plugs.SetAdminActorCookies do
  @moduledoc """
  Writes the AshAdmin actor cookies (`actor_resource`, `actor_primary_key`,
  `actor_domain`, `actor_action`, `actor_authorizing`) based on the signed-in
  user so `/admin` actions see the admin as actor without requiring a manual
  "Set as actor" click.

  AshAdmin's router `__session__` builder runs a `cookies_to_replicate`
  pass that overwrites any session keys carrying these names with whatever
  it finds in `conn.req_cookies` — replicating the JS-set cookies that the
  admin sidebar normally writes. Setting the cookies ourselves is the only
  way to keep the actor populated across LiveView mounts.
  """

  import Plug.Conn

  alias Intellispark.Accounts.User

  def init(opts), do: opts

  def call(%Plug.Conn{assigns: %{current_user: %User{id: id}}} = conn, _opts) do
    conn
    |> maybe_put_cookie("actor_resource", "User")
    |> maybe_put_cookie("actor_domain", "Accounts")
    |> maybe_put_cookie("actor_action", "read")
    |> maybe_put_cookie("actor_primary_key", id)
    |> maybe_put_cookie("actor_authorizing", "true")
    |> maybe_put_cookie("actor_paused", "false")
    |> maybe_seed_tenant_cookie()
  end

  def call(conn, _opts), do: conn

  defp maybe_seed_tenant_cookie(conn) do
    case conn.assigns[:current_school] do
      %{id: school_id} -> maybe_put_cookie(conn, "tenant", school_id)
      _ -> conn
    end
  end

  defp maybe_put_cookie(conn, name, value) do
    if conn.req_cookies[name] == value do
      conn
    else
      put_resp_cookie(conn, name, value, http_only: false, same_site: "Lax")
    end
  end
end
