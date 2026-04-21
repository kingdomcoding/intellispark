defmodule Intellispark.Assessments.Changes.MarkInProgress do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case changeset.data.state do
      :assigned ->
        changeset
        |> AshStateMachine.transition_state(:in_progress)
        |> Ash.Changeset.force_change_attribute(:first_opened_at, DateTime.utc_now())

      _ ->
        changeset
    end
  end
end
