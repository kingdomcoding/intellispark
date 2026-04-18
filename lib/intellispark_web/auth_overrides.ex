defmodule IntellisparkWeb.AuthOverrides do
  @moduledoc """
  Brand overrides for the AshAuthentication.Phoenix sign-in / register / reset
  / confirm flows. Mirrors Intellispark's real login UI: whitesmoke background,
  centered white card, wordmark at top, orange pill buttons.

  Each class is set on the exact subcomponent AshAuthentication.Phoenix reads it
  from — `Password.Input` for field styling, `Password.SignInForm`/`RegisterForm`/
  `ResetForm` for submit buttons, `Password` for inter-form toggler links.
  """

  use AshAuthentication.Phoenix.Overrides

  # ---- Outer LiveView wrappers ----
  # The *Live modules render an outermost <div> around everything. The default
  # uses `grid h-screen place-items-center` — place-items-center shrinks the
  # grid cell content to its intrinsic width, which collapses our w-full card
  # down to the input's natural width. Neutralize it so our inner
  # Components.SignIn/Reset/Confirm handle all layout.

  override AshAuthentication.Phoenix.SignInLive do
    set :root_class, "w-full"
  end

  override AshAuthentication.Phoenix.ResetLive do
    set :root_class, "w-full"
  end

  override AshAuthentication.Phoenix.ConfirmLive do
    set :root_class, "w-full"
  end

  # Shared class fragments
  @card_class "w-full max-w-[28rem] rounded-card bg-white shadow-card p-lg space-y-md"
  @field_class "mb-sm"
  @label_class "block text-sm font-medium text-abbey mb-1"
  @input_class "w-full rounded-lg border border-abbey/20 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-chocolate focus:border-transparent"
  @input_class_with_error "w-full rounded-lg border border-indicator-low-border px-3 py-2 focus:outline-none focus:ring-2 focus:ring-indicator-low-border"
  @submit_class "w-full inline-flex items-center justify-center gap-2 rounded-pill bg-chocolate text-white font-medium px-6 py-3 hover:bg-chocolate-600 focus-visible:ring-2 focus-visible:ring-chocolate focus-visible:ring-offset-2 transition-colors"
  @toggler_class "text-sm text-brand hover:text-brand-700 font-medium"

  # ---- Page-level containers (stacked, centered) ----

  override AshAuthentication.Phoenix.Components.SignIn do
    set :show_banner, true

    set :root_class,
        "min-h-screen bg-whitesmoke flex flex-col items-center justify-center px-xs gap-md"

    set :strategy_class, "w-full max-w-[28rem]"
  end

  override AshAuthentication.Phoenix.Components.Reset do
    set :root_class,
        "min-h-screen bg-whitesmoke flex flex-col items-center justify-center px-xs gap-md"

    set :strategy_class, "w-full max-w-[28rem]"
  end

  # ---- Banner (Intellispark wordmark) ----

  override AshAuthentication.Phoenix.Components.Banner do
    set :image_url, "/images/logo-horizontal.png"
    set :dark_image_url, "/images/logo-horizontal.png"
    set :text, nil
    # Keep the default visibility gating (block in light, hidden in dark for
    # light image; inverse for dark image). Tailwind v4's default dark strategy
    # is prefers-color-scheme, so omitting `dark:hidden` on the light image
    # makes both logos render when the OS is dark.
    set :image_class, "h-12 w-auto mx-auto block dark:hidden"
    set :dark_image_class, "h-12 w-auto mx-auto hidden dark:block"
    set :root_class, "w-full flex justify-center"
  end

  # ---- Password wrapper + toggler links ("Forgot your password?" / "Need an account?") ----

  override AshAuthentication.Phoenix.Components.Password do
    set :root_class, @card_class
    set :interstitial_class, "flex flex-row justify-between items-center gap-sm mt-sm"
    set :toggler_class, @toggler_class
    set :hide_class, "hidden"
  end

  # ---- Form inputs + submit button (shared by SignInForm, RegisterForm, ResetForm) ----
  # The submit button renders via Password.Input.submit, so submit_class lives here,
  # not on the individual *Form modules (where it would be silently ignored — the
  # AshAuthentication override macro resolves by __CALLER__.module at compile time).

  override AshAuthentication.Phoenix.Components.Password.Input do
    set :field_class, @field_class
    set :label_class, @label_class
    set :input_class, @input_class
    set :input_class_with_error, @input_class_with_error
    set :submit_class, @submit_class
    set :identity_input_label, "Email"
    set :password_input_label, "Password"
    set :password_confirmation_input_label, "Confirm password"
  end

  # ---- Per-form button text + heading (these DO live on form-specific modules,
  # because each form reads @label_class and :button_text from its own override namespace) ----

  override AshAuthentication.Phoenix.Components.Password.SignInForm do
    set :button_text, "Sign In"
    set :disable_button_text, "Signing in…"
    set :slot_class, nil
    set :label_class, "sr-only"
  end

  override AshAuthentication.Phoenix.Components.Password.RegisterForm do
    set :button_text, "Create Account"
    set :disable_button_text, "Creating account…"
    set :slot_class, nil
    set :label_class, "sr-only"
  end

  override AshAuthentication.Phoenix.Components.Password.ResetForm do
    set :button_text, "Send Reset Link"
    set :disable_button_text, "Sending…"
    set :slot_class, nil
    set :label_class, "sr-only"
  end

  # ---- Reset page (set new password) ----

  override AshAuthentication.Phoenix.Components.Reset.Form do
    set :label_class, "sr-only"
    set :form_class, nil
  end
end
