import Config

System.put_env(
  "TOKEN_SIGNING_SECRET",
  System.get_env("TOKEN_SIGNING_SECRET") ||
    "test-token-signing-secret-deterministic-and-not-for-production-use"
)

config :intellispark,
  cloak_key_fallback:
    <<87, 12, 45, 98, 177, 23, 214, 56, 201, 88, 9, 143, 61, 219, 99, 12, 44, 55, 201, 72, 180,
      14, 251, 6, 109, 88, 162, 33, 219, 199, 44, 76>>

config :intellispark, Intellispark.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "postgres"),
  # Force the test database regardless of POSTGRES_DB in the environment.
  # The dev .env sets POSTGRES_DB=intellispark_dev for the running server;
  # tests must never touch that.
  database: "intellispark_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :intellispark, IntellisparkWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "sNrdKA00Eek0cmT7vNGv5/9u4s5d8ATw16oWf7bJPzMlW44XzSSqRI/QELYMpViL",
  server: false

config :intellispark, Intellispark.Mailer, adapter: Swoosh.Adapters.Test

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view, enable_expensive_runtime_checks: true

config :phoenix, sort_verified_routes_query_params: true

config :intellispark, Oban, testing: :manual
