import Config

config :intellispark,
  cloak_key_fallback:
    <<228, 69, 14, 38, 147, 111, 237, 225, 8, 9, 172, 59, 243, 121, 14, 172, 33, 115, 73, 8, 172,
      47, 141, 240, 79, 24, 146, 96, 247, 223, 211, 152>>

config :intellispark, Intellispark.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "postgres"),
  database: System.get_env("POSTGRES_DB", "intellispark_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :intellispark, Intellispark.Mailer, adapter: Swoosh.Adapters.Local

config :intellispark, IntellisparkWeb.Endpoint,
  url: [
    host: System.get_env("PHX_HOST", "localhost"),
    scheme: System.get_env("PHX_URL_SCHEME", "http"),
    port: String.to_integer(System.get_env("PHX_URL_PORT", "4800"))
  ],
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4800"))],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "mOWNGEljpHDvs2C7A70AOzb3A4o1U7zhIs98VheMXBvvc8JFBDvrVy/FFyuDLAVB",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:intellispark, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:intellispark, ~w(--watch)]}
  ]

config :intellispark, IntellisparkWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*\.po$",
      ~r"lib/intellispark_web/router\.ex$",
      ~r"lib/intellispark_web/(controllers|live|components)/.*\.(ex|heex)$"
    ]
  ]

config :intellispark, dev_routes: true

config :logger, :default_formatter, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true
