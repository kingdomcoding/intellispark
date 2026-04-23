defmodule Intellispark.Assessments.Resiliency.Assessment do
  @moduledoc """
  ScholarCentric resiliency survey instance for one student. Parallels
  `SurveyAssignment` but with a canon-defined question set (QuestionBank)
  and a fixed 6-skill taxonomy. State machine: :assigned -> :in_progress
  -> :submitted, plus :expired. On :submit an Oban job scores the
  responses into 6 `SkillScore` rows.
  """

  use Intellispark.Resource, domain: Intellispark.Assessments

  paper_trail do
    attributes_as_attributes [:school_id]
  end

  pub_sub do
    module IntellisparkWeb.Endpoint
    prefix ""
    publish_all :create, ["resiliency_assessments:student", :student_id]
    publish_all :update, ["resiliency_assessments:student", :student_id]
  end

  postgres do
    table "resiliency_assessments"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :grade_band, :atom do
      allow_nil? false
      constraints one_of: [:grades_3_5, :grades_6_8, :grades_9_12]
      public? true
    end

    attribute :version, :string, allow_nil?: false, public?: true

    attribute :state, :atom do
      allow_nil? false
      default :assigned
      constraints one_of: [:assigned, :in_progress, :submitted, :expired]
      public? true
    end

    attribute :token, :string, allow_nil?: false, public?: false

    attribute :assigned_at, :utc_datetime_usec,
      allow_nil?: false,
      default: &DateTime.utc_now/0,
      public?: true

    attribute :submitted_at, :utc_datetime_usec, public?: true
    attribute :expires_at, :utc_datetime_usec, public?: true

    timestamps()
  end

  identities do
    identity :unique_token, [:token]
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :student, Intellispark.Students.Student, allow_nil?: false
    belongs_to :assigned_by, Intellispark.Accounts.User, allow_nil?: false

    has_many :responses, Intellispark.Assessments.Resiliency.Response,
      destination_attribute: :assessment_id
  end

  actions do
    defaults [:read, :destroy]

    create :assign do
      accept [:student_id, :grade_band]
      change Intellispark.Assessments.Resiliency.Changes.StampAssignment
    end

    update :start do
      accept []
      require_atomic? false
      change set_attribute(:state, :in_progress)
    end

    update :submit do
      accept []
      require_atomic? false
      change set_attribute(:state, :submitted)
      change set_attribute(:submitted_at, &DateTime.utc_now/0)
      change Intellispark.Assessments.Resiliency.Changes.EnqueueScoring
    end

    update :expire do
      accept []
      change set_attribute(:state, :expired)
    end

    read :by_token do
      argument :token, :string, allow_nil?: false
      filter expr(token == ^arg(:token))
      multitenancy :bypass
      get? true
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.AdminOrClinicalRoleInSchool
    end

    policy action(:assign) do
      authorize_if IntellisparkWeb.Policies.AdminOrClinicalRoleInSchool
    end

    policy action(:assign) do
      authorize_if {IntellisparkWeb.Policies.RequiresTier, tier: :pro}
    end

    policy action(:by_token) do
      authorize_if always()
    end

    policy action([:start, :submit, :expire]) do
      authorize_if IntellisparkWeb.Policies.AdminOrClinicalRoleInSchool
    end
  end
end
