defmodule Intellispark.Accounts.User.Senders.SendConfirmationEmail do
  use AshAuthentication.Sender

  import Swoosh.Email

  alias Intellispark.Mailer
  alias IntellisparkWeb.Endpoint

  def send(user, token, _opts) do
    new()
    |> to(to_string(user.email))
    |> from({"Intellispark", "no-reply@intellispark.local"})
    |> subject("Confirm your Intellispark account")
    |> html_body(html(token))
    |> text_body(text(token))
    |> Mailer.deliver!()
  end

  defp html(token) do
    """
    <p>Welcome to Intellispark.</p>
    <p>Please confirm your email to activate your account:</p>
    <p><a href="#{confirm_url(token)}" style="color: #ee5c11;">Confirm my email</a></p>
    """
  end

  defp text(token) do
    "Confirm your Intellispark email: #{confirm_url(token)}"
  end

  defp confirm_url(token) do
    Endpoint.url() <> "/auth/user/confirm_new_user?confirm=" <> URI.encode_www_form(token)
  end
end
