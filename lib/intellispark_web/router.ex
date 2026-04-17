defmodule IntellisparkWeb.Router do
  use IntellisparkWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {IntellisparkWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
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

  scope "/", IntellisparkWeb do
    pipe_through :browser

    get "/", PageController, :home

    ash_authentication_live_session :maybe_user,
      on_mount: {IntellisparkWeb.LiveUserAuth, :live_user_optional} do
      live "/styleguide", StyleguideLive
    end

    auth_routes AuthController, Intellispark.Accounts.User, path: "/auth"
    sign_out_route AuthController

    sign_in_route(
      register_path: "/register",
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
