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

    resource Intellispark.Assessments.SurveyTemplateVersion do
      define :list_survey_template_versions, action: :read
      define :get_survey_template_version, action: :read, get_by: [:id]
    end

    resource Intellispark.Assessments.SurveyTemplateVersion.Version

    resource Intellispark.Assessments.SurveyResponse do
      define :list_survey_responses, action: :read
      define :get_survey_response, action: :read, get_by: [:id]
    end

    resource Intellispark.Assessments.SurveyResponse.Version

    resource Intellispark.Assessments.SurveyAssignment do
      define :list_survey_assignments, action: :read
      define :get_survey_assignment, action: :read, get_by: [:id]

      define :get_survey_assignment_by_token,
        action: :by_token,
        args: [:token],
        get?: true

      define :assign_survey,
        action: :assign_to_student,
        args: [:student_id, :survey_template_id]

      define :bulk_assign_survey,
        action: :bulk_assign_to_students,
        args: [:student_ids, :survey_template_id, :mode]

      define :save_survey_progress,
        action: :save_progress,
        args: [:question_id, :answer_text, :answer_values]

      define :submit_survey, action: :submit
      define :expire_survey, action: :expire
      define :touch_last_reminded, action: :touch_last_reminded
      define :archive_survey_assignment, action: :destroy
    end

    resource Intellispark.Assessments.SurveyAssignment.Version

    resource Intellispark.Assessments.Resiliency.Assessment do
      define :list_resiliency_assessments, action: :read
      define :get_resiliency_assessment, action: :read, get_by: [:id]

      define :get_resiliency_assessment_by_token,
        action: :by_token,
        args: [:token],
        get?: true

      define :assign_resiliency, action: :assign, args: [:student_id, :grade_band]
      define :start_resiliency, action: :start
      define :submit_resiliency, action: :submit
      define :expire_resiliency, action: :expire
    end

    resource Intellispark.Assessments.Resiliency.Assessment.Version

    resource Intellispark.Assessments.Resiliency.Response do
      define :list_resiliency_responses, action: :read

      define :upsert_resiliency_response,
        action: :upsert_answer,
        args: [:assessment_id, :question_id, :value]
    end

    resource Intellispark.Assessments.Resiliency.Response.Version

    resource Intellispark.Assessments.Resiliency.SkillScore do
      define :list_resiliency_skill_scores, action: :read

      define :upsert_resiliency_skill_score,
        action: :upsert,
        args: [:student_id, :skill, :score_value, :level, :answered_count]
    end

    resource Intellispark.Assessments.Resiliency.SkillScore.Version
  end
end
