defmodule Intellispark.Assessments.SurveyTemplateVersion do
  @moduledoc """
  Immutable snapshot of a SurveyTemplate + its questions at publish
  time. Created by the `SurveyTemplate.:publish` action. Assignments
  pin to a version so template edits don't retroactively change
  response schemas.
  """

  use Intellispark.Resource, domain: Intellispark.Assessments

  admin do
    label_field :id
  end

  paper_trail do
    attributes_as_attributes [:school_id, :survey_template_id]
  end

  postgres do
    table "survey_template_versions"
    repo Intellispark.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :school_id
    global? false
  end

  attributes do
    uuid_primary_key :id

    attribute :schema, :map, allow_nil?: false, public?: true
    attribute :published_at, :utc_datetime_usec, allow_nil?: false, public?: true

    timestamps()
  end

  relationships do
    belongs_to :school, Intellispark.Accounts.School, allow_nil?: false

    belongs_to :survey_template, Intellispark.Assessments.SurveyTemplate,
      allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:survey_template_id, :schema, :published_at]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if IntellisparkWeb.Policies.StaffEditsStudentsInSchool
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if always()
    end
  end
end
