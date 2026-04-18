defmodule Intellispark.Accounts.User.Senders.SendConfirmationEmail do
  use AshAuthentication.Sender
  use IntellisparkWeb, :verified_routes

  import Swoosh.Email

  alias Intellispark.Mailer
  alias IntellisparkWeb.EmailLayout

  def send(user, token, _opts) do
    url = confirm_url(token)

    new()
    |> to(to_string(user.email))
    |> from({"Intellispark", "no-reply@intellispark.local"})
    |> subject("Confirm your Intellispark account")
    |> html_body(html(url))
    |> text_body(text(url))
    |> Mailer.deliver!()
  end

  defp html(url) do
    EmailLayout.wrap(
      heading: "Welcome to Intellispark",
      body_html: """
      <p style="margin:0 0 12px 0;">Confirm your email to activate your account and get started.</p>
      <p style="margin:0;">This link will expire in 2 days.</p>
      """,
      cta_url: url,
      cta_label: "Confirm my email"
    )
  end

  defp text(url) do
    """
    Welcome to Intellispark.

    Confirm your email to activate your account:
    #{url}

    This link expires in 2 days. If you didn't sign up, ignore this email.
    """
  end

  defp confirm_url(token) do
    url(~p"/confirm_new_user/#{token}")
  end
end
