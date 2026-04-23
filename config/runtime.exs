import Config

if config_env() != :test do
  if System.get_env("PHX_SERVER") do
    config :intellispark, IntellisparkWeb.Endpoint, server: true
  end

  config :intellispark, IntellisparkWeb.Endpoint,
    http: [port: String.to_integer(System.get_env("PORT", "4800"))]
end

if config_env() == :prod do
  for key <- ~w(DATABASE_URL SECRET_KEY_BASE PHX_HOST CLOAK_KEY TOKEN_SIGNING_SECRET) do
    unless System.get_env(key) do
      raise """
      environment variable #{key} is missing.

      Set it in /srv/intellispark/.env.prod on the production host.
      """
    end
  end

  database_url = System.get_env("DATABASE_URL")

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :intellispark, Intellispark.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "15"),
    socket_options: maybe_ipv6

  secret_key_base = System.get_env("SECRET_KEY_BASE")
  host = System.get_env("PHX_HOST")
  port = String.to_integer(System.get_env("PORT") || "4800")

  config :intellispark, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :intellispark, IntellisparkWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base

  config :intellispark, Intellispark.Mailer,
    adapter: Swoosh.Adapters.Resend,
    api_key: System.get_env("RESEND_API_KEY") || ""
end
