defmodule Intellispark.Assessments.Actions.BulkAssignSurvey do
  @moduledoc """
  Generic action implementing `SurveyAssignment.:bulk_assign_to_students`.
  Phase F-stub; Phase G fills in the bulk_create implementation.
  """

  use Ash.Resource.Actions.Implementation

  @impl true
  def run(_input, _opts, _context), do: {:ok, %Ash.BulkResult{status: :success, records: [], errors: []}}
end
