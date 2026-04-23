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

  # Two topics so LiveViews can subscribe at the right granularity:
  # - "students:school:<school_id>" for the /students list LiveView
  # - "students:<id>"               for the /students/:id hub LiveView
  pub_sub do
    module IntellisparkWeb.Endpoint
    # Reset the default 'resource' prefix so LiveView subs match.
    prefix ""
    publish_all :create, ["students:school", :school_id]
    publish_all :update, ["students:school", :school_id]
    publish_all :update, ["students", :id]
    publish_all :destroy, ["students:school", :school_id]
    publish_all :destroy, ["students", :id]
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
    attribute :email, :string, public?: true
    attribute :phone, :string, public?: true

    attribute :gender, :atom do
      constraints one_of: [:male, :female, :non_binary, :prefer_not_to_say, :other]
      public? true
    end

    attribute :ethnicity_race, :atom do
      constraints one_of: [
                    :american_indian_or_alaska_native,
                    :asian,
                    :black_or_african_american,
                    :hispanic_or_latino,
                    :native_hawaiian_or_pacific_islander,
                    :white,
                    :two_or_more_races,
                    :prefer_not_to_say
                  ]

      public? true
    end

    timestamps()
  end

  identities do
    identity :unique_external_id_per_school, [:school_id, :external_id],
      where: expr(not is_nil(external_id))
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false

    has_many :student_tags, Intellispark.Students.StudentTag

    many_to_many :tags, Intellispark.Students.Tag do
      through Intellispark.Students.StudentTag
      source_attribute_on_join_resource :student_id
      destination_attribute_on_join_resource :tag_id
    end

    has_many :student_statuses, Intellispark.Students.StudentStatus

    belongs_to :current_status, Intellispark.Students.Status do
      attribute_writable? true
      public? true
    end

    has_many :flags, Intellispark.Flags.Flag
    has_many :actions, Intellispark.Support.Action
    has_many :supports, Intellispark.Support.Support
    has_many :notes, Intellispark.Support.Note
    has_many :high_fives, Intellispark.Recognition.HighFive
    has_many :survey_assignments, Intellispark.Assessments.SurveyAssignment
    has_many :indicator_scores, Intellispark.Indicators.IndicatorScore
    has_many :team_memberships, Intellispark.Teams.TeamMembership
    has_many :key_connections, Intellispark.Teams.KeyConnection
    has_many :strengths, Intellispark.Teams.Strength
  end

  aggregates do
    count :open_flags_count, :flags do
      filter expr(status != :closed)
      public? true
    end

    count :open_supports_count, :supports do
      filter expr(status in [:offered, :in_progress])
      public? true
    end

    count :recent_high_fives_count, :high_fives do
      filter expr(sent_at >= ago(30, :day))
      public? true
    end

    count :open_survey_assignments_count, :survey_assignments do
      filter expr(state in [:assigned, :in_progress])
      public? true
    end
  end

  calculations do
    calculate :district_id, :uuid, expr(school.district_id)

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

    calculate :age_in_years,
              :integer,
              expr(fragment("EXTRACT(YEAR FROM age(?))::int", date_of_birth))

    calculate :belonging,
              :atom,
              {Intellispark.Students.Calculations.IndicatorLevel, dimension: :belonging}

    calculate :connection,
              :atom,
              {Intellispark.Students.Calculations.IndicatorLevel, dimension: :connection}

    calculate :decision_making,
              :atom,
              {Intellispark.Students.Calculations.IndicatorLevel, dimension: :decision_making}

    calculate :engagement,
              :atom,
              {Intellispark.Students.Calculations.IndicatorLevel, dimension: :engagement}

    calculate :readiness,
              :atom,
              {Intellispark.Students.Calculations.IndicatorLevel, dimension: :readiness}

    calculate :relationship_skills,
              :atom,
              {Intellispark.Students.Calculations.IndicatorLevel, dimension: :relationship_skills}

    calculate :relationships_adult,
              :atom,
              {Intellispark.Students.Calculations.IndicatorLevel, dimension: :relationships_adult}

    calculate :relationships_networks,
              :atom,
              {Intellispark.Students.Calculations.IndicatorLevel,
               dimension: :relationships_networks}

    calculate :relationships_peer,
              :atom,
              {Intellispark.Students.Calculations.IndicatorLevel, dimension: :relationships_peer}

    calculate :self_awareness,
              :atom,
              {Intellispark.Students.Calculations.IndicatorLevel, dimension: :self_awareness}

    calculate :self_management,
              :atom,
              {Intellispark.Students.Calculations.IndicatorLevel, dimension: :self_management}

    calculate :social_awareness,
              :atom,
              {Intellispark.Students.Calculations.IndicatorLevel, dimension: :social_awareness}

    calculate :well_being,
              :atom,
              {Intellispark.Students.Calculations.IndicatorLevel, dimension: :well_being}
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
        :photo_url,
        :email,
        :phone,
        :gender,
        :ethnicity_race
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
        :photo_url,
        :email,
        :phone,
        :gender,
        :ethnicity_race
      ]

      require_atomic? false
    end

    create :upsert_from_sis do
      accept [
        :first_name,
        :last_name,
        :preferred_name,
        :date_of_birth,
        :grade_level,
        :enrollment_status,
        :external_id,
        :email,
        :phone,
        :gender,
        :ethnicity_race
      ]

      upsert? true
      upsert_identity :unique_external_id_per_school

      upsert_fields [
        :first_name,
        :last_name,
        :preferred_name,
        :date_of_birth,
        :grade_level,
        :enrollment_status,
        :email,
        :phone,
        :gender,
        :ethnicity_race,
        :updated_at
      ]
    end

    update :set_status do
      argument :status_id, :uuid, allow_nil?: false
      require_atomic? false
      change Intellispark.Students.Changes.SetStudentStatus
    end

    update :clear_status do
      require_atomic? false
      change Intellispark.Students.Changes.ClearStudentStatus
    end

    update :upload_photo do
      argument :photo, :map, allow_nil?: false
      require_atomic? false
      change Intellispark.Students.Changes.UploadStudentPhoto
    end

    update :remove_tag do
      argument :tag_id, :uuid, allow_nil?: false
      require_atomic? false
      change Intellispark.Students.Changes.RemoveTag
    end

    update :archive do
      accept []
      require_atomic? false
      change set_attribute(:archived_at, &DateTime.utc_now/0)
    end

    update :unarchive do
      accept []
      require_atomic? false
      change set_attribute(:archived_at, nil)
    end

    update :mark_withdrawn do
      accept []
      require_atomic? false
      change set_attribute(:enrollment_status, :withdrawn)
    end

    update :transfer do
      argument :destination_school_id, :uuid, allow_nil?: false
      require_atomic? false
      change Intellispark.Students.Changes.TransferToSchool
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.AdminOrClinicalRoleInSchool
      authorize_if IntellisparkWeb.Policies.TeacherOnlySeesTeamStudents
    end

    policy action_type(:create) do
      authorize_if IntellisparkWeb.Policies.ActorBelongsToTenantSchool
    end

    policy action_type(:destroy) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end

    policy action_type(:update) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end

    policy action(:archive) do
      authorize_if IntellisparkWeb.Policies.AdminOrClinicalRoleInSchool
    end

    policy action(:unarchive) do
      authorize_if IntellisparkWeb.Policies.AdminOrClinicalRoleInSchool
    end

    policy action(:mark_withdrawn) do
      authorize_if IntellisparkWeb.Policies.AdminOrClinicalRoleInSchool
    end

    policy action(:transfer) do
      authorize_if IntellisparkWeb.Policies.DistrictAdminOfSchool
    end

    policy action(:transfer) do
      authorize_if {IntellisparkWeb.Policies.RequiresTier, tier: :pro}
    end
  end
end
