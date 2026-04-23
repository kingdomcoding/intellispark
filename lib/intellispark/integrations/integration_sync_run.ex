defmodule Intellispark.Integrations.IntegrationSyncRun do
  @moduledoc """
  One run of a provider sync. Transitions through
  `:pending → :running → {:succeeded, :failed, :partially_succeeded}`.
  Records processed / created / updated / failed counts + a relation to
  per-record `IntegrationSyncError` rows.
  """

  use Intellispark.Resource,
    domain: Intellispark.Integrations,
    extensions: [AshStateMachine]

  paper_trail do
    attributes_as_attributes [:school_id, :provider_id]
  end

  pub_sub do
    module IntellisparkWeb.Endpoint
    prefix ""
    publish_all :create, ["sync_runs:school", :school_id]
    publish_all :update, ["sync_runs:school", :school_id]
  end

  postgres do
    table "integration_sync_runs"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  state_machine do
    state_attribute :status
    initial_states [:pending]
    default_initial_state :pending

    transitions do
      transition :start, from: [:pending], to: :running
      transition :succeed, from: [:running], to: :succeeded
      transition :partial_succeed, from: [:running], to: :partially_succeeded
      transition :fail, from: [:pending, :running], to: :failed
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :atom do
      allow_nil? false
      default :pending
      constraints one_of: [:pending, :running, :succeeded, :failed, :partially_succeeded]
      public? true
    end

    attribute :started_at, :utc_datetime_usec, public?: true
    attribute :completed_at, :utc_datetime_usec, public?: true
    attribute :records_processed, :integer, default: 0, public?: true
    attribute :records_created, :integer, default: 0, public?: true
    attribute :records_updated, :integer, default: 0, public?: true
    attribute :records_failed, :integer, default: 0, public?: true

    attribute :trigger_source, :atom do
      default :scheduled
      constraints one_of: [:scheduled, :manual, :webhook]
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :provider, Intellispark.Integrations.IntegrationProvider, allow_nil?: false

    has_many :errors, Intellispark.Integrations.IntegrationSyncError,
      destination_attribute: :sync_run_id
  end

  calculations do
    calculate :district_id, :uuid, expr(school.district_id)
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:provider_id, :trigger_source]
    end

    update :start do
      accept []
      change set_attribute(:started_at, &DateTime.utc_now/0)
      change transition_state(:running)
    end

    update :succeed do
      accept [:records_processed, :records_created, :records_updated]
      require_atomic? false
      change set_attribute(:completed_at, &DateTime.utc_now/0)
      change transition_state(:succeeded)
    end

    update :partial_succeed do
      accept [:records_processed, :records_created, :records_updated, :records_failed]
      require_atomic? false
      change set_attribute(:completed_at, &DateTime.utc_now/0)
      change transition_state(:partially_succeeded)
    end

    update :fail do
      accept [:records_failed]
      require_atomic? false
      change set_attribute(:completed_at, &DateTime.utc_now/0)
      change transition_state(:failed)
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
end
