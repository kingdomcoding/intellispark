defmodule Intellispark.Assessments.SurveyTemplate do
  @moduledoc """
  Per-school survey template. Contains questions + publish workflow.
  Each :publish action snapshots the template tree into a
  SurveyTemplateVersion row; assignments pin to the version that was
  current at create time so template edits don't retroactively change
  response schemas.
  """

  use Intellispark.Resource, domain: Intellispark.Assessments

  admin do
    label_field :name
  end

  paper_trail do
    attributes_as_attributes [:school_id]
  end

  postgres do
    table "survey_templates"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false, public?: true
    attribute :description, :string, public?: true
    attribute :published?, :boolean, allow_nil?: false, default: false, public?: true
    attribute :duration_minutes, :integer, default: 5, public?: true
    attribute :current_version_id, :uuid, public?: true

    timestamps()
  end

  identities do
    identity :unique_name_per_school, [:school_id, :name]
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false

    has_many :questions, Intellispark.Assessments.SurveyQuestion,
      destination_attribute: :survey_template_id

    has_many :versions, Intellispark.Assessments.SurveyTemplateVersion,
      destination_attribute: :survey_template_id

    belongs_to :current_version, Intellispark.Assessments.SurveyTemplateVersion,
      attribute_writable?: true,
      define_attribute?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :description, :duration_minutes]
    end

    update :update do
      primary? true
      accept [:name, :description, :duration_minutes]
      require_atomic? false
    end

    update :publish do
      accept []
      require_atomic? false
      change Intellispark.Assessments.Changes.PublishSurveyTemplate
    end

    update :unpublish do
      accept []
      require_atomic? false
      change set_attribute(:published?, false)
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

    policy action([:publish, :unpublish]) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end
  end
end
