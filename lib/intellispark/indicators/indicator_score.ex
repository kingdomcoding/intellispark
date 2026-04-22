defmodule Intellispark.Indicators.IndicatorScore do
  @moduledoc """
  One row per (student, dimension). Upserted by the scoring worker
  after SurveyAssignment :submit; historical values preserved via
  AshPaperTrail.
  """

  use Intellispark.Resource, domain: Intellispark.Indicators

  admin do
    label_field :id
  end

  paper_trail do
    attributes_as_attributes [:school_id, :student_id, :dimension, :level]
  end

  pub_sub do
    module IntellisparkWeb.Endpoint
    prefix ""
    publish_all :create, ["indicator_scores:student", :student_id]
    publish_all :update, ["indicator_scores:student", :student_id]
  end

  postgres do
    table "indicator_scores"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :dimension, :atom do
      allow_nil? false
      constraints one_of: Intellispark.Indicators.Dimension.all()
      public? true
    end

    attribute :level, :atom do
      allow_nil? false
      constraints one_of: [:low, :moderate, :high]
      public? true
    end

    attribute :score_value, :float, allow_nil?: false, public?: true
    attribute :answered_count, :integer, allow_nil?: false, default: 0, public?: true

    attribute :last_computed_at, :utc_datetime_usec,
      allow_nil?: false,
      default: &DateTime.utc_now/0,
      public?: true

    timestamps()
  end

  identities do
    identity :unique_per_student_dimension, [:student_id, :dimension]
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false
    belongs_to :student, Intellispark.Students.Student, allow_nil?: false

    belongs_to :source_survey_assignment,
               Intellispark.Assessments.SurveyAssignment,
               allow_nil?: true
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :student_id,
        :dimension,
        :level,
        :score_value,
        :answered_count,
        :last_computed_at,
        :source_survey_assignment_id
      ]

      upsert? true
      upsert_identity :unique_per_student_dimension

      upsert_fields [
        :level,
        :score_value,
        :answered_count,
        :last_computed_at,
        :source_survey_assignment_id,
        :updated_at
      ]
    end

    read :for_student do
      argument :student_id, :uuid, allow_nil?: false
      filter expr(student_id == ^arg(:student_id))
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end
end
