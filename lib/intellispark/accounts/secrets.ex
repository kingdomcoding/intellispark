defmodule Intellispark.Accounts.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Intellispark.Accounts.User,
        _opts,
        _context
      ) do
    case System.get_env("TOKEN_SIGNING_SECRET") do
      nil ->
        {:error,
         "TOKEN_SIGNING_SECRET is not set. Generate one with `mix phx.gen.secret 64` and add it to .env"}

      secret ->
        {:ok, secret}
    end
  end
end
