defmodule Intellispark.Accounts.User.Senders.SendConfirmationEmail do
  use AshAuthentication.Sender
  use IntellisparkWeb, :verified_routes

  import Swoosh.Email

  alias Intellispark.Mailer

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
    url(~p"/confirm_new_user/#{token}")
  end
end
