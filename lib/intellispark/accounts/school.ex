defmodule Intellispark.Accounts.School do
  use Intellispark.Resource, domain: Intellispark.Accounts

  admin do
    label_field :name
  end

  postgres do
    table "schools"
    repo Intellispark.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :slug, :string, allow_nil?: false, public?: true
    timestamps()
  end

  identities do
    identity :unique_slug_per_district, [:district_id, :slug]
  end

  relationships do
    belongs_to :district, Intellispark.Accounts.District, allow_nil?: false
    has_many :memberships, Intellispark.Accounts.UserSchoolMembership
    has_many :terms, Intellispark.Accounts.SchoolTerm
    has_one :subscription, Intellispark.Billing.SchoolSubscription
    has_one :onboarding_state, Intellispark.Billing.SchoolOnboardingState
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :slug, :district_id]
      change Intellispark.Accounts.Changes.SeedBillingState
    end

    update :update do
      accept [:name, :slug]
      primary? true
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:memberships, :user])
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfSchool
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfSchool
    end
  end
end
