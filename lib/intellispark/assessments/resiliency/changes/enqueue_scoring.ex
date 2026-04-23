defmodule Intellispark.Assessments.Resiliency.Changes.EnqueueScoring do
  @moduledoc false
  use Ash.Resource.Change

  alias Intellispark.Assessments.Resiliency.Workers.SkillScoreWorker

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, result ->
      tenant = to_string(result.school_id)

      %{"assessment_id" => result.id, "tenant" => tenant}
      |> SkillScoreWorker.new()
      |> Oban.insert!()

      {:ok, result}
    end)
  end
end
