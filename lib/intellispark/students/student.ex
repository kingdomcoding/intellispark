defmodule Intellispark.Students.Student do
  @moduledoc """
  K-12 student. Tenant-scoped to school_id. Paper-trailed, archivable.
  Reads are filtered by school via attribute multi-tenancy + policies.
  """

  use Intellispark.Resource, domain: Intellispark.Students

  admin do
    label_field :display_name
  end

  # Copy school_id onto the auto-generated Version resource so its own
  # multitenancy block (injected by AshPaperTrail) has a real column to
  # reference. Without this, paper-trail inserts fail with "No such
  # attribute school_id for resource Student.Version".
  paper_trail do
    attributes_as_attributes [:school_id]
  end

  postgres do
    table "students"
    repo Intellispark.Repo

    identity_wheres_to_sql unique_external_id_per_school: "external_id IS NOT NULL"
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :first_name, :string, allow_nil?: false, public?: true
    attribute :last_name, :string, allow_nil?: false, public?: true
    attribute :preferred_name, :string, public?: true
    attribute :date_of_birth, :date, public?: true

    attribute :grade_level, :integer do
      constraints min: -1, max: 16
      public? true
    end

    attribute :enrollment_status, :atom do
      allow_nil? false
      default :active
      constraints one_of: [:active, :inactive, :graduated, :withdrawn]
      public? true
    end

    attribute :external_id, :string, public?: true
    attribute :photo_url, :string, public?: true

    timestamps()
  end

  identities do
    identity :unique_external_id_per_school, [:school_id, :external_id],
      where: expr(not is_nil(external_id))
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
  end

  calculations do
    calculate :display_name,
              :string,
              expr(
                fragment(
                  "coalesce(?, ? || ' ' || ?)",
                  preferred_name,
                  first_name,
                  last_name
                )
              )

    calculate :initials,
              :string,
              expr(
                fragment(
                  "upper(substring(?, 1, 1) || substring(?, 1, 1))",
                  first_name,
                  last_name
                )
              )
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :first_name,
        :last_name,
        :preferred_name,
        :date_of_birth,
        :grade_level,
        :enrollment_status,
        :external_id,
        :photo_url
      ]
    end

    update :update do
      primary? true

      accept [
        :first_name,
        :last_name,
        :preferred_name,
        :date_of_birth,
        :grade_level,
        :enrollment_status,
        :external_id,
        :photo_url
      ]

      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.StaffReadsStudentsInSchool
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end
  end
end
