defmodule Intellispark.Integrations.EmbedToken do
  @moduledoc """
  Long-lived token (1 year default) that authorizes the public
  `/embed/student/:token` view consumed by partner iframes. One token
  per (student_id, audience); rotation via `:regenerate`, revocation
  via `:revoke`. The `:by_token` read action bypasses multitenancy so
  unauthenticated visitors can resolve the embed.
  """

  use Intellispark.Resource, domain: Intellispark.Integrations

  paper_trail do
    attributes_as_attributes [:school_id, :student_id]
  end

  postgres do
    table "embed_tokens"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id
    attribute :token, :string, allow_nil?: false, public?: false

    attribute :audience, :atom do
      allow_nil? false
      default :xello
      constraints one_of: [:xello]
      public? true
    end

    attribute :expires_at, :utc_datetime_usec, allow_nil?: false, public?: true
    attribute :revoked_at, :utc_datetime_usec, public?: true

    timestamps()
  end

  identities do
    identity :unique_token, [:token]
    identity :unique_per_student_audience, [:student_id, :audience]
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :student, Intellispark.Students.Student, allow_nil?: false
    belongs_to :created_by, Intellispark.Accounts.User, allow_nil?: false
  end

  calculations do
    calculate :district_id, :uuid, expr(school.district_id)
  end

  actions do
    defaults [:read]

    create :mint do
      accept [:student_id, :audience]
      change Intellispark.Integrations.Changes.GenerateEmbedToken
      change Intellispark.Integrations.Changes.StampEmbedCreatedBy

      change fn changeset, _ctx ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :expires_at,
          DateTime.utc_now() |> DateTime.add(365, :day)
        )
      end
    end

    update :regenerate do
      accept []
      require_atomic? false
      change Intellispark.Integrations.Changes.GenerateEmbedToken
      change set_attribute(:revoked_at, nil)

      change fn changeset, _ctx ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :expires_at,
          DateTime.utc_now() |> DateTime.add(365, :day)
        )
      end
    end

    update :revoke do
      accept []
      change set_attribute(:revoked_at, &DateTime.utc_now/0)
    end

    read :by_token do
      argument :token, :string, allow_nil?: false
      filter expr(token == ^arg(:token))
      multitenancy :bypass
    end
  end

  policies do
    policy action(:by_token) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfSchool
    end

    policy action_type(:create) do
      authorize_if IntellisparkWeb.Policies.DistrictAdminForSchoolScopedCreate
    end

    policy action_type(:update) do
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfSchool
    end
  end
end
