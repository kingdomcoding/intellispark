defmodule Intellispark.Assessments.SurveyQuestion do
  @moduledoc """
  A single question on a survey template. Belongs to a template;
  ordered by :position. Type-specific config lives in :metadata JSONB.
  """

  use Intellispark.Resource, domain: Intellispark.Assessments

  admin do
    label_field :prompt
  end

  paper_trail do
    attributes_as_attributes [:school_id, :survey_template_id]
  end

  postgres do
    table "survey_questions"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :prompt, :string, allow_nil?: false, public?: true
    attribute :help_text, :string, public?: true
    attribute :position, :integer, allow_nil?: false, default: 0, public?: true
    attribute :required?, :boolean, allow_nil?: false, default: false, public?: true

    attribute :question_type, :atom do
      allow_nil? false
      default :short_text

      constraints one_of: [
                    :short_text,
                    :long_text,
                    :single_choice,
                    :multi_choice,
                    :likert_5
                  ]

      public? true
    end

    attribute :metadata, :map, default: %{}, public?: true

    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false

    belongs_to :survey_template, Intellispark.Assessments.SurveyTemplate, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :survey_template_id,
        :prompt,
        :help_text,
        :position,
        :required?,
        :question_type,
        :metadata
      ]
    end

    update :update do
      primary? true
      accept [:prompt, :help_text, :position, :required?, :question_type, :metadata]
      require_atomic? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end

    policy action_type(:create) do
      authorize_if IntellisparkWeb.Policies.ActorBelongsToTenantSchool
    end

    policy action_type([:update, :destroy]) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end
  end
end
