defmodule Intellispark.Billing.SchoolOnboardingState do
  @moduledoc """
  Per-school onboarding wizard state. `current_step` enum advances
  through `:school_profile → :invite_coadmins → :starter_tags →
  :sis_provider → :pick_tier → :done`. Each step stamps its own
  `_completed_at`; `completed_at` marks full completion. One per School
  (identity `:unique_school`). Seeded on `School.:create`.
  """

  use Intellispark.Resource, domain: Intellispark.Billing

  admin do
    label_field :current_step
  end

  postgres do
    table "school_onboarding_states"
    repo Intellispark.Repo
  end

  @steps [:school_profile, :invite_coadmins, :starter_tags, :sis_provider, :pick_tier, :done]

  attributes do
    uuid_primary_key :id

    attribute :current_step, :atom do
      allow_nil? false
      default :school_profile
      constraints one_of: @steps
      public? true
    end

    attribute :school_profile_completed_at, :utc_datetime_usec, public?: true
    attribute :invite_coadmins_completed_at, :utc_datetime_usec, public?: true
    attribute :starter_tags_completed_at, :utc_datetime_usec, public?: true
    attribute :sis_provider_completed_at, :utc_datetime_usec, public?: true
    attribute :pick_tier_completed_at, :utc_datetime_usec, public?: true
    attribute :completed_at, :utc_datetime_usec, public?: true

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
      accept [:school_id]
    end

    update :advance_step do
      accept []

      argument :step, :atom,
        allow_nil?: false,
        constraints: [one_of: @steps]

      require_atomic? false
      change Intellispark.Billing.Changes.StampStepCompletion
      change set_attribute(:current_step, arg(:step))
    end

    update :complete do
      accept []
      require_atomic? false
      change set_attribute(:current_step, :done)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type([:read, :update]) do
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfSchool
    end

    policy action_type(:create) do
      authorize_if always()
    end
  end

  def steps, do: @steps
end
