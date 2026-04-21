defmodule Intellispark.Assessments.SurveyResponse do
  @moduledoc """
  One response per (assignment, question). Upserted by the `:save_progress`
  action on SurveyAssignment; finalised at `:submit`. Two nullable answer
  columns cover all five question types without a polymorphic table.
  """

  use Intellispark.Resource, domain: Intellispark.Assessments

  admin do
    label_field :id
  end

  paper_trail do
    attributes_as_attributes [:school_id, :survey_assignment_id, :question_id]
  end

  postgres do
    table "survey_responses"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :answer_text, :string, public?: true
    attribute :answer_values, {:array, :string}, default: [], public?: true

    attribute :answered_at, :utc_datetime_usec,
      allow_nil?: false,
      default: &DateTime.utc_now/0

    attribute :survey_assignment_id, :uuid, allow_nil?: false, public?: true

    timestamps()
  end

  identities do
    identity :unique_response_per_question, [:survey_assignment_id, :question_id]
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :question, Intellispark.Assessments.SurveyQuestion, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :survey_assignment_id,
        :question_id,
        :answer_text,
        :answer_values,
        :answered_at
      ]

      upsert? true
      upsert_identity :unique_response_per_question

      upsert_fields [:answer_text, :answer_values, :answered_at, :updated_at]
    end

    update :update do
      primary? true
      accept [:answer_text, :answer_values, :answered_at]
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
      authorize_if always()
    end

    policy action_type([:create, :update]) do
      authorize_if always()
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end
end
