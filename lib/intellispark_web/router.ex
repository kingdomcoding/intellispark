defmodule IntellisparkWeb.Router do
  use IntellisparkWeb, :router
  use AshAuthentication.Phoenix.Router

  import AshAdmin.Router
  import Phoenix.LiveDashboard.Router

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

  pipeline :public_browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {IntellisparkWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  pipeline :embed do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {IntellisparkWeb.Layouts, :root}
    plug :put_embed_csp
  end

  defp put_embed_csp(conn, _opts) do
    conn
    |> Plug.Conn.put_resp_header(
      "content-security-policy",
      "frame-ancestors *.xello.com *.app.xello.com;"
    )
    |> Plug.Conn.delete_resp_header("x-frame-options")
  end

  scope "/", IntellisparkWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated_user,
      on_mount: [
        {IntellisparkWeb.LiveUserAuth, :live_user_required},
        IntellisparkWeb.LiveHooks.LoadOnboardingState
      ] do
      post "/set-school", SchoolController, :set_active

      live "/students", StudentLive.Index
      live "/students/risk", RiskDashboardLive.Index, :show
      live "/students/:id", StudentLive.Show
      live "/lists", CustomListLive.Index
      live "/lists/:id", CustomListLive.Show
      live "/insights", InsightsLive
      live "/me/email-preferences", UserSettingsLive.EmailPreferences, :show
      live "/onboarding", OnboardingLive.Show, :show
      live "/admin/integrations", AdminLive.Integrations.Index, :index
    end

    get "/insights/export.csv", InsightsController, :export
  end

  scope "/admin" do
    pipe_through [:browser]

    live_dashboard "/dashboard",
      metrics: IntellisparkWeb.Telemetry,
      on_mount: [
        {IntellisparkWeb.LiveUserAuth, :live_user_required},
        {IntellisparkWeb.LiveUserAuth, :require_district_admin}
      ]
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
    pipe_through :public_browser

    live_session :public, on_mount: [] do
      live "/", LandingLive.Show
      live "/demo", DemoLive.Show
      live "/engineering-journal", JournalLive.Index
      live "/engineering-journal/adr/:id", JournalLive.AdrShow
      live "/engineering-journal/phase/:slug", JournalLive.PhaseShow
      live "/about", AboutLive.Show
    end

    post "/demo/:persona", DemoController, :create_session
  end

  scope "/", IntellisparkWeb do
    pipe_through :browser

    ash_authentication_live_session :maybe_user,
      on_mount: {IntellisparkWeb.LiveUserAuth, :live_user_optional} do
      live "/styleguide", StyleguideLive
      live "/invitations/:token", InvitationLive.Accept
      live "/high-fives/:token", HighFiveViewLive, :show
      live "/surveys/:token", SurveyLive.Show, :show
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

  scope "/api", IntellisparkWeb do
    pipe_through [:api, IntellisparkWeb.Plugs.LoadXelloProvider]

    post "/xello/webhook", XelloWebhookController, :receive
  end

  scope "/embed", IntellisparkWeb do
    pipe_through :embed

    live_session :embed, on_mount: [] do
      live "/student/:embed_token", EmbedLive.Student, :show
    end
  end

  if Application.compile_env(:intellispark, :dev_routes) do
    scope "/dev" do
      pipe_through :browser
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
