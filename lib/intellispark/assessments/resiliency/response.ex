defmodule Intellispark.Assessments.Resiliency.Response do
  @moduledoc """
  One response per (assessment, question_id) with a 0-5 Likert value.
  Upserted by `:upsert_answer` during the student's token-access survey
  flow. Read by the SkillScoreWorker after :submit.
  """

  use Intellispark.Resource, domain: Intellispark.Assessments

  paper_trail do
    attributes_as_attributes [:school_id, :assessment_id, :question_id]
  end

  postgres do
    table "resiliency_responses"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id
    attribute :question_id, :string, allow_nil?: false, public?: true

    attribute :value, :integer do
      allow_nil? false
      constraints min: 0, max: 5
      public? true
    end

    attribute :answered_at, :utc_datetime_usec,
      allow_nil?: false,
      default: &DateTime.utc_now/0

    timestamps()
  end

  identities do
    identity :unique_per_assessment_question, [:assessment_id, :question_id]
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false

    belongs_to :assessment, Intellispark.Assessments.Resiliency.Assessment,
      allow_nil?: false
  end

  actions do
    defaults [:read]

    create :upsert_answer do
      accept [:assessment_id, :question_id, :value]
      upsert? true
      upsert_identity :unique_per_assessment_question
      upsert_fields [:value, :answered_at, :updated_at]
      change set_attribute(:answered_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.AdminOrClinicalRoleInSchool
    end

    policy action(:upsert_answer) do
      authorize_if always()
    end
  end
end
