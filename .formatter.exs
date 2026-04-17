[
  import_deps: [
    :ash,
    :ash_postgres,
    :ash_phoenix,
    :ash_authentication,
    :ash_authentication_phoenix,
    :ash_oban,
    :ash_paper_trail,
    :ash_archival,
    :ash_state_machine,
    :ash_admin,
    :oban,
    :phoenix
  ],
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,test}/**/*.{ex,exs}",
    "priv/*/seeds.exs",
    "priv/*/migrations/*.exs"
  ],
  plugins: [Spark.Formatter, Phoenix.LiveView.HTMLFormatter],
  subdirectories: ["priv/*/migrations"]
]
