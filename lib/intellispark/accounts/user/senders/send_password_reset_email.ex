defmodule Intellispark.Accounts.User.Senders.SendPasswordResetEmail do
  use AshAuthentication.Sender

  import Swoosh.Email

  alias Intellispark.Mailer
  alias IntellisparkWeb.Endpoint

  def send(user, token, _opts) do
    new()
    |> to({display_name(user), to_string(user.email)})
    |> from({"Intellispark", "no-reply@intellispark.local"})
    |> subject("Reset your Intellispark password")
    |> html_body(html(token))
    |> text_body(text(token))
    |> Mailer.deliver!()
  end

  defp html(token) do
    """
    <p>Hi there,</p>
    <p>Click the link below to reset your Intellispark password. It expires in 24 hours.</p>
    <p><a href="#{reset_url(token)}" style="color: #ee5c11;">Reset my password</a></p>
    <p>If you didn't request this, you can safely ignore this email.</p>
    """
  end

  defp text(token) do
    "Reset your Intellispark password: #{reset_url(token)}\n\nIf you didn't request this, ignore this email."
  end

  defp reset_url(token) do
    Endpoint.url() <> "/auth/user/password/reset?token=" <> URI.encode_www_form(token)
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
