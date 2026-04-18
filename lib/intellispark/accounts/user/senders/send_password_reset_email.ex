defmodule Intellispark.Accounts.User.Senders.SendPasswordResetEmail do
  use AshAuthentication.Sender
  use IntellisparkWeb, :verified_routes

  import Swoosh.Email

  alias Intellispark.Mailer
  alias IntellisparkWeb.EmailLayout

  def send(user, token, _opts) do
    url = reset_url(token)

    new()
    |> to({display_name(user), to_string(user.email)})
    |> from({"Intellispark", "no-reply@intellispark.local"})
    |> subject("Reset your Intellispark password")
    |> html_body(html(url))
    |> text_body(text(url))
    |> Mailer.deliver!()
  end

  defp html(url) do
    EmailLayout.wrap(
      heading: "Reset your password",
      body_html: """
      <p style="margin:0 0 12px 0;">Click the button below to set a new Intellispark password.</p>
      <p style="margin:0;">This link expires in 24 hours.</p>
      """,
      cta_url: url,
      cta_label: "Reset my password",
      footer_html:
        "If you didn't request this, you can safely ignore this email — your password won't change."
    )
  end

  defp text(url) do
    """
    Reset your Intellispark password:
    #{url}

    This link expires in 24 hours. If you didn't request this, ignore this email.
    """
  end

  defp reset_url(token) do
    url(~p"/password-reset/#{token}")
  end

  defp display_name(user) do
    case {user.first_name, user.last_name} do
      {nil, nil} -> to_string(user.email)
      {first, nil} -> first
      {nil, last} -> last
      {first, last} -> "#{first} #{last}"
    end
  end
end
