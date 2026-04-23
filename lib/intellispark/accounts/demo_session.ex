defmodule Intellispark.Accounts.DemoSession do
  use Ash.Resource,
    otp_app: :intellispark,
    domain: Intellispark.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "demo_sessions"
    repo Intellispark.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :persona, :atom do
      constraints one_of: [:district_admin, :counselor, :xello_embed]
      allow_nil? false
      public? true
    end

    attribute :ip_hash, :string, public?: false
    attribute :user_agent_hash, :string, public?: false
    attribute :expires_at, :utc_datetime_usec, public?: true

    timestamps()
  end

  relationships do
    belongs_to :user, Intellispark.Accounts.User, public?: true
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:persona, :user_id, :ip_hash, :user_agent_hash, :expires_at]
    end
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end
end
