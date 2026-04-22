defmodule Intellispark.Indicators.Oban.ComputeIndicatorScoresWorker do
  @moduledoc """
  Oban worker that computes all 13 SEL dimension scores for a
  SurveyAssignment's submission. Enqueued by the
  `EnqueueIndicatorScoring` after_action change on
  `SurveyAssignment.:submit`.
  """

  use Oban.Worker, queue: :indicators, max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"assignment_id" => id, "school_id" => school_id}}) do
    Intellispark.Indicators.compute_for_assignment(id, school_id)
  end
end
