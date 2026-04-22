defmodule Intellispark.Billing.SchoolSubscription do
  @moduledoc """
  Per-school subscription record. Tier (`:starter | :plus | :pro`) gates
  feature access via `RequiresTier` + `Intellispark.Tiers`. Status tracks
  billing lifecycle (`:active | :past_due | :cancelled`). One per School
  (identity `:unique_school`). Seeded automatically on `School.:create`.
  """

  use Intellispark.Resource, domain: Intellispark.Billing

  admin do
    label_field :tier
  end

  paper_trail do
    attributes_as_attributes [:school_id]
  end

  postgres do
    table "school_subscriptions"
    repo Intellispark.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :tier, :atom do
      allow_nil? false
      default :starter
      constraints one_of: [:starter, :plus, :pro]
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      default :active
      constraints one_of: [:active, :past_due, :cancelled]
      public? true
    end

    attribute :seats, :integer, default: 0, public?: true

    attribute :started_at, :utc_datetime_usec,
      allow_nil?: false,
      default: &DateTime.utc_now/0,
      public?: true

    attribute :renews_at, :utc_datetime_usec, public?: true
    attribute :stripe_subscription_id, :string, public?: false

    timestamps()
  end

  identities do
    identity :unique_school, [:school_id]
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
  end

  calculations do
    calculate :district_id, :uuid, expr(school.district_id)
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:school_id, :tier, :status, :seats, :renews_at]
    end

    update :set_tier do
      accept []

      argument :tier, :atom,
        allow_nil?: false,
        constraints: [one_of: [:starter, :plus, :pro]]

      require_atomic? false
      change set_attribute(:tier, arg(:tier))
    end

    update :mark_past_due do
      accept []
      change set_attribute(:status, :past_due)
    end

    update :cancel do
      accept []
      change set_attribute(:status, :cancelled)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:school, :memberships, :user])
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfSchool
    end

    policy action_type([:create, :update]) do
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfSchool
    end
  end
end
