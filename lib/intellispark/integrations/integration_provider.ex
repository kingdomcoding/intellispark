defmodule Intellispark.Integrations.IntegrationProvider do
  @moduledoc """
  Per-school SIS or integration provider. Stores encrypted credentials,
  activation state, and last-sync timestamps. Xello is PRO-tier only;
  CSV is first-class; OneRoster / Clever / ClassLink have stubbed
  transformers in this phase.
  """

  use Intellispark.Resource, domain: Intellispark.Integrations

  paper_trail do
    attributes_as_attributes [:school_id]
    ignore_attributes [:credentials]
  end

  postgres do
    table "integration_providers"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  @provider_types [:csv, :oneroster, :clever, :classlink, :xello, :custom]

  attributes do
    uuid_primary_key :id

    attribute :provider_type, :atom do
      allow_nil? false
      constraints one_of: @provider_types
      public? true
    end

    attribute :name, :string, allow_nil?: false, public?: true

    attribute :credentials, Intellispark.Encrypted.Map do
      allow_nil? false
      default fn -> %{} end
      public? false
    end

    attribute :active?, :boolean, default: true, public?: true
    attribute :last_synced_at, :utc_datetime_usec, public?: true
    attribute :last_success_at, :utc_datetime_usec, public?: true
    attribute :last_failure_at, :utc_datetime_usec, public?: true

    timestamps()
  end

  identities do
    identity :unique_type_per_school, [:school_id, :provider_type]
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false

    has_many :sync_runs, Intellispark.Integrations.IntegrationSyncRun,
      destination_attribute: :provider_id
  end

  calculations do
    calculate :district_id, :uuid, expr(school.district_id)
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:provider_type, :name, :credentials, :active?]
    end

    update :update_credentials do
      accept [:credentials]
      require_atomic? false
    end

    update :activate do
      accept []
      change set_attribute(:active?, true)
    end

    update :deactivate do
      accept []
      change set_attribute(:active?, false)
    end

    update :stamp_sync_finished do
      accept []

      argument :status, :atom,
        allow_nil?: false,
        constraints: [one_of: [:succeeded, :failed, :partially_succeeded]]

      require_atomic? false
      change Intellispark.Integrations.Changes.StampSyncFinished
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:school, :memberships, :user])
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfSchool
    end

    policy action(:create) do
      authorize_if IntellisparkWeb.Policies.RequiresTierForXello
      authorize_if IntellisparkWeb.Policies.DistrictAdminForSchoolScopedCreate
    end

    policy action_type(:update) do
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfSchool
    end
  end
end
