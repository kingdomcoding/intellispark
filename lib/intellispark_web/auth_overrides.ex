defmodule IntellisparkWeb.AuthOverrides do
  @moduledoc """
  Brand overrides for the AshAuthentication.Phoenix sign-in / register / reset
  / confirm flows. Mirrors Intellispark's real login UI: whitesmoke background,
  centered white card, wordmark at top, orange pill buttons.
  """

  use AshAuthentication.Phoenix.Overrides

  override AshAuthentication.Phoenix.Components.Banner do
    set :image_url, "/images/logo-horizontal.png"
    set :dark_image_url, "/images/logo-horizontal.png"
    set :text, nil
    set :image_class, "h-12 w-auto mx-auto"
    set :root_class, "mb-md"
  end

  override AshAuthentication.Phoenix.Components.SignIn do
    set :show_banner, true
    set :root_class, "min-h-screen bg-whitesmoke flex items-center justify-center px-md"
  end

  override AshAuthentication.Phoenix.Components.Reset do
    set :root_class, "min-h-screen bg-whitesmoke flex items-center justify-center px-md"
  end

  override AshAuthentication.Phoenix.Components.Password do
    set :root_class,
        "w-full max-w-md rounded-card bg-white shadow-card p-lg space-y-md"

    set :label_class, "block text-sm font-medium text-abbey mb-1"

    set :input_class,
        "w-full rounded-lg border border-abbey/20 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-chocolate"

    set :submit_class,
        "w-full inline-flex items-center justify-center gap-2 rounded-pill bg-chocolate text-white font-medium px-6 py-3 hover:bg-chocolate-600 focus-visible:ring-2 focus-visible:ring-chocolate focus-visible:ring-offset-2"

    set :button_text, "Sign In"
  end

  override AshAuthentication.Phoenix.Components.Password.RegisterForm do
    set :root_class,
        "w-full max-w-md rounded-card bg-white shadow-card p-lg space-y-md"

    set :label_class, "block text-sm font-medium text-abbey mb-1"

    set :input_class,
        "w-full rounded-lg border border-abbey/20 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-chocolate"

    set :submit_class,
        "w-full inline-flex items-center justify-center rounded-pill bg-chocolate text-white font-medium px-6 py-3 hover:bg-chocolate-600"

    set :button_text, "Create Account"
  end

  override AshAuthentication.Phoenix.Components.Password.ResetForm do
    set :root_class,
        "w-full max-w-md rounded-card bg-white shadow-card p-lg space-y-md"

    set :label_class, "block text-sm font-medium text-abbey mb-1"

    set :input_class,
        "w-full rounded-lg border border-abbey/20 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-chocolate"

    set :submit_class,
        "w-full inline-flex items-center justify-center rounded-pill bg-chocolate text-white font-medium px-6 py-3 hover:bg-chocolate-600"

    set :button_text, "Send Reset Link"
  end
end
