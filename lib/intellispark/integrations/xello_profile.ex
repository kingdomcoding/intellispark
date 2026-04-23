defmodule Intellispark.Integrations.XelloProfile do
  @moduledoc """
  Per-student Xello snapshot. Flat map/array attributes for each section
  Xello exposes (personality style, learning style, career clusters,
  interests, etc.). Upserted by the `/api/xello/webhook` receiver.
  One profile per student; paper-trailed for audit.
  """

  use Intellispark.Resource, domain: Intellispark.Integrations

  paper_trail do
    attributes_as_attributes [:school_id, :student_id]
  end

  postgres do
    table "xello_profiles"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :personality_style, :map, default: %{}, public?: true
    attribute :learning_style, :map, default: %{}, public?: true
    attribute :education_goals, :string, public?: true
    attribute :favorite_career_clusters, {:array, :string}, default: [], public?: true
    attribute :skills, {:array, :string}, default: [], public?: true
    attribute :interests, {:array, :string}, default: [], public?: true
    attribute :birthplace, :string, public?: true
    attribute :live_in, :string, public?: true
    attribute :family_roots, :string, public?: true
    attribute :suggested_clusters, {:array, :string}, default: [], public?: true

    attribute :last_synced_at, :utc_datetime_usec,
      allow_nil?: false,
      default: &DateTime.utc_now/0,
      public?: true

    timestamps()
  end

  identities do
    identity :unique_per_student, [:student_id]
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :student, Intellispark.Students.Student, allow_nil?: false
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :student_id,
        :personality_style,
        :learning_style,
        :education_goals,
        :favorite_career_clusters,
        :skills,
        :interests,
        :birthplace,
        :live_in,
        :family_roots,
        :suggested_clusters,
        :last_synced_at
      ]
    end

    create :upsert_from_webhook do
      accept [
        :student_id,
        :personality_style,
        :learning_style,
        :education_goals,
        :favorite_career_clusters,
        :skills,
        :interests,
        :birthplace,
        :live_in,
        :family_roots,
        :suggested_clusters
      ]

      upsert? true
      upsert_identity :unique_per_student

      upsert_fields [
        :personality_style,
        :learning_style,
        :education_goals,
        :favorite_career_clusters,
        :skills,
        :interests,
        :birthplace,
        :live_in,
        :family_roots,
        :suggested_clusters,
        :last_synced_at,
        :updated_at
      ]

      change set_attribute(:last_synced_at, &DateTime.utc_now/0)
    end

    update :update_from_webhook do
      accept [
        :personality_style,
        :learning_style,
        :education_goals,
        :favorite_career_clusters,
        :skills,
        :interests,
        :birthplace,
        :live_in,
        :family_roots,
        :suggested_clusters
      ]

      require_atomic? false
      change set_attribute(:last_synced_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:school, :memberships, :user])
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfSchool
    end

    policy action_type([:create, :update]) do
      authorize_if always()
    end
  end
end
