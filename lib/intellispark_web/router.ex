defmodule IntellisparkWeb.Router do
  use IntellisparkWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {IntellisparkWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", IntellisparkWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/styleguide", StyleguideLive
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
