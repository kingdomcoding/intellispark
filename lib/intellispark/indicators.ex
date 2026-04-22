defmodule Intellispark.Indicators do
  @moduledoc """
  Domain for SEL dimension indicators (Phase 8). Holds IndicatorScore
  + the scoring algorithm + the recompute mix task. The 13 dimensions
  themselves live as a plain module constant at
  `Intellispark.Indicators.Dimension`.
  """

  use Ash.Domain,
    otp_app: :intellispark,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Intellispark.Indicators.IndicatorScore do
      define :list_indicator_scores, action: :read
      define :get_indicator_score, action: :read, get_by: [:id]

      define :indicator_scores_for_student,
        action: :for_student,
        args: [:student_id]

      define :upsert_indicator_score,
        action: :create,
        args: [:student_id, :dimension, :level, :score_value, :answered_count]
    end

    resource Intellispark.Indicators.IndicatorScore.Version
  end

  defdelegate compute_for_assignment(assignment_id),
    to: Intellispark.Indicators.Scoring

  defdelegate compute_for_assignment(assignment_id, school_id),
    to: Intellispark.Indicators.Scoring

  defdelegate summary_for(student_ids, dimension, school_id),
    to: Intellispark.Indicators.Insights

  defdelegate individual_for(student_ids, dimension, school_id),
    to: Intellispark.Indicators.Insights
end
