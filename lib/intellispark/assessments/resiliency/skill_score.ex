defmodule Intellispark.Assessments.Resiliency.SkillScore do
  @moduledoc """
  Per-student per-skill score produced by the SkillScoreWorker after a
  ResiliencyAssessment is submitted. Idempotent via the
  `:unique_per_student_skill` identity. Score_value uses a 0-5 Likert
  mean; `level` bands that into :low/:moderate/:high.
  """

  use Intellispark.Resource, domain: Intellispark.Assessments

  paper_trail do
    attributes_as_attributes [:school_id, :student_id, :skill]
  end

  pub_sub do
    module IntellisparkWeb.Endpoint
    prefix ""
    publish_all :create, ["resiliency_skill_scores:student", :student_id]
    publish_all :update, ["resiliency_skill_scores:student", :student_id]
    publish_all :create, ["resiliency_skill_scores:school", :school_id]
    publish_all :update, ["resiliency_skill_scores:school", :school_id]
  end

  postgres do
    table "resiliency_skill_scores"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :skill, :atom do
      allow_nil? false

      constraints one_of: [
                    :confidence,
                    :persistence,
                    :organization,
                    :getting_along,
                    :resilience,
                    :curiosity
                  ]

      public? true
    end

    attribute :score_value, :float, allow_nil?: false, public?: true

    attribute :level, :atom do
      allow_nil? false
      constraints one_of: [:low, :moderate, :high]
      public? true
    end

    attribute :answered_count, :integer, allow_nil?: false, default: 0, public?: true

    attribute :last_computed_at, :utc_datetime_usec,
      allow_nil?: false,
      default: &DateTime.utc_now/0,
      public?: true

    timestamps()
  end

  identities do
    identity :unique_per_student_skill, [:student_id, :skill]
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :student, Intellispark.Students.Student, allow_nil?: false
    belongs_to :assessment, Intellispark.Assessments.Resiliency.Assessment
  end

  actions do
    defaults [:read]

    create :upsert do
      accept [:student_id, :skill, :score_value, :level, :answered_count, :assessment_id]
      upsert? true
      upsert_identity :unique_per_student_skill

      upsert_fields [
        :score_value,
        :level,
        :answered_count,
        :last_computed_at,
        :assessment_id,
        :updated_at
      ]

      change set_attribute(:last_computed_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.AdminOrClinicalRoleInSchool
    end

    policy action(:upsert) do
      authorize_if always()
    end
  end
end
