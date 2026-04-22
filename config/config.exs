import Config

config :intellispark,
  ecto_repos: [Intellispark.Repo],
  generators: [binary_id: true, timestamp_type: :utc_datetime_usec],
  ash_domains: [
    Intellispark.Accounts,
    Intellispark.Students,
    Intellispark.Flags,
    Intellispark.Support,
    Intellispark.Recognition,
    Intellispark.Assessments,
    Intellispark.Indicators,
    Intellispark.Teams,
    Intellispark.Integrations,
    Intellispark.Automations
  ]

config :ash, :include_embedded_source_by_default?, false
config :ash, :default_page_type, :keyset
config :ash, :policies, no_filter_static_forbidden_reads?: false

config :spark, Spark.Formatter, remove_parens?: true

config :intellispark, IntellisparkWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: IntellisparkWeb.ErrorHTML, json: IntellisparkWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Intellispark.PubSub,
  live_view: [signing_salt: "yO1Ofkin"]

config :esbuild,
  version: "0.25.4",
  intellispark: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

config :tailwind,
  version: "4.1.12",
  intellispark: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

config :intellispark, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.PG,
  queues: [
    default: 10,
    emails: 20,
    ingestion: 5,
    notifications: 20,
    indicators: 10
  ],
  repo: Intellispark.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)},
    {Oban.Plugins.Cron,
     crontab: [
       {"0 8 * * *", Intellispark.Flags.Oban.DailyFollowupReminderWorker},
       {"0 7 * * *", Intellispark.Support.Oban.DailyActionReminderWorker},
       {"5 7 * * *", Intellispark.Support.Oban.SupportExpirationReminderWorker},
       {"0 9 * * *", Intellispark.Assessments.Oban.DailySurveyReminderScanner},
       {"0 7 * * 1", Intellispark.Digest.WeeklyDigestWorker}
     ]}
  ]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :swoosh, :api_client, Swoosh.ApiClient.Finch

import_config "#{config_env()}.exs"
