defmodule Intellispark.Accounts.DemoResetLog do
  use Ash.Resource,
    otp_app: :intellispark,
    domain: Intellispark.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "demo_reset_logs"
    repo Intellispark.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :sessions_destroyed, :integer, allow_nil?: false, public?: true, default: 0
    attribute :ran_at, :utc_datetime_usec, allow_nil?: false, public?: true

    timestamps()
  end

  actions do
    defaults [:read]

    create :create do
      accept [:sessions_destroyed, :ran_at]
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end
end
