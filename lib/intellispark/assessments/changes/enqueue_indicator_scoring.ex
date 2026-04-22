defmodule Intellispark.Assessments.Changes.EnqueueIndicatorScoring do
  @moduledoc false
  use Ash.Resource.Change

  alias Intellispark.Indicators.Oban.ComputeIndicatorScoresWorker

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _cs, assignment ->
      %{assignment_id: assignment.id, school_id: assignment.school_id}
      |> ComputeIndicatorScoresWorker.new()
      |> Oban.insert!()

      {:ok, assignment}
    end)
  end
end
