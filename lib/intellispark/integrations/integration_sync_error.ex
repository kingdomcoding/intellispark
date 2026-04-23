defmodule Intellispark.Integrations.IntegrationSyncError do
  @moduledoc """
  Dead-letter entry. One row per failed record in a bulk upsert. Admins
  can edit `raw_payload` + retry via the `:retry` action, which re-runs
  the single payload through the transformer + upsert.
  """

  use Intellispark.Resource, domain: Intellispark.Integrations

  paper_trail do
    attributes_as_attributes [:school_id, :sync_run_id]
  end

  postgres do
    table "integration_sync_errors"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id
    attribute :raw_payload, :map, allow_nil?: false, public?: true
    attribute :error_message, :string, allow_nil?: false, public?: true

    attribute :error_kind, :atom do
      default :validation
      constraints one_of: [:validation, :network, :transform, :policy, :unknown]
      public? true
    end

    attribute :resolved?, :boolean, default: false, public?: true
    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false

    belongs_to :sync_run, Intellispark.Integrations.IntegrationSyncRun, allow_nil?: false
  end

  actions do
    defaults [:read]

    create :record do
      primary? true
      accept [:sync_run_id, :raw_payload, :error_message, :error_kind]
    end

    update :retry do
      accept [:raw_payload]
      require_atomic? false
      change set_attribute(:resolved?, true)
    end

    update :mark_resolved do
      accept []
      change set_attribute(:resolved?, true)
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
