defmodule Intellispark.Assessments do
  @moduledoc """
  Domain for surveys, check-ins, and (Phase 8) SEL-dimension scoring.
  Phase 7 ships the generic survey framework: SurveyTemplate with
  versioning, SurveyQuestion, SurveyAssignment with token-based
  student access, and SurveyResponse with auto-save upsert semantics.
  All tenant-scoped on school_id.
  """

  use Ash.Domain,
    otp_app: :intellispark,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Intellispark.Assessments.SurveyTemplate do
      define :list_survey_templates, action: :read
      define :get_survey_template, action: :read, get_by: [:id]
      define :create_survey_template, action: :create, args: [:name, :description]
      define :update_survey_template, action: :update
      define :publish_survey_template, action: :publish
      define :unpublish_survey_template, action: :unpublish
      define :archive_survey_template, action: :destroy
    end

    resource Intellispark.Assessments.SurveyTemplate.Version

    resource Intellispark.Assessments.SurveyQuestion do
      define :list_survey_questions, action: :read
      define :get_survey_question, action: :read, get_by: [:id]

      define :create_survey_question,
        action: :create,
        args: [:survey_template_id, :position, :prompt, :question_type]

      define :update_survey_question, action: :update
      define :archive_survey_question, action: :destroy
    end

    resource Intellispark.Assessments.SurveyQuestion.Version
  end
end
