defmodule IntellisparkWeb.Router do
  use IntellisparkWeb, :router
  use AshAuthentication.Phoenix.Router

  import AshAdmin.Router

  @doc """
  Session hook passed to the `ash_admin` macro. AshAdmin's router builds its
  own live_session dict from scratch (via `AshAdmin.Router.__session__/3`) and
  does not forward the Plug session, so our `:live_user_required` on_mount
  can't see the signed-in user. This hook ferries `user_token` across.
  """
  def admin_auth_session(conn) do
    case Plug.Conn.get_session(conn, "user_token") do
      nil -> %{}
      token -> %{"user_token" => token}
    end
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {IntellisparkWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
    plug IntellisparkWeb.Plugs.AssignCurrentSchool
    plug IntellisparkWeb.Plugs.SetAdminActorCookies
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  scope "/", IntellisparkWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated_user,
      on_mount: {IntellisparkWeb.LiveUserAuth, :live_user_required} do
      post "/set-school", SchoolController, :set_active
    end
  end

  scope "/" do
    pipe_through [:browser]

    ash_admin "/admin",
      session: [{IntellisparkWeb.Router, :admin_auth_session, []}],
      on_mount: [
        {IntellisparkWeb.LiveUserAuth, :live_user_required},
        {IntellisparkWeb.LiveUserAuth, :require_district_admin}
      ]
  end

  scope "/", IntellisparkWeb do
    pipe_through :browser

    get "/", PageController, :home

    ash_authentication_live_session :maybe_user,
      on_mount: {IntellisparkWeb.LiveUserAuth, :live_user_optional} do
      live "/styleguide", StyleguideLive
      live "/invitations/:token", InvitationLive.Accept
    end

    auth_routes AuthController, Intellispark.Accounts.User, path: "/auth"

    # One-click sign-out from the header dropdown — no intermediate confirmation
    # LiveView. DELETE is CSRF-protected by :protect_from_forgery in the
    # :browser pipeline and invoked via <.link method="delete">.
    delete "/sign-out", AuthController, :sign_out

    # No register_path — account creation is invite-only via /invitations/:token
    # (see ADR-003). The :register_with_password action on the User resource is
    # kept for internal use by SchoolInvitation's AcceptInvitation change.
    sign_in_route(
      reset_path: "/reset",
      auth_routes_prefix: "/auth",
      on_mount: [{IntellisparkWeb.LiveUserAuth, :live_no_user}],
      overrides: [IntellisparkWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )

    reset_route(
      auth_routes_prefix: "/auth",
      overrides: [IntellisparkWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )

    confirm_route(
      Intellispark.Accounts.User,
      :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [IntellisparkWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )
  end

  scope "/", IntellisparkWeb do
    pipe_through :api
    get "/healthz", HealthController, :check
  end

  if Application.compile_env(:intellispark, :dev_routes) do
    scope "/dev" do
      pipe_through :browser
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
