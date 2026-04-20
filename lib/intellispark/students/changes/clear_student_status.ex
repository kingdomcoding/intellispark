defmodule Intellispark.Students.Changes.ClearStudentStatus do
  @moduledoc """
  Called by Student.clear_status/2. Nils `current_status_id` on the student
  and stamps `cleared_at` on any active StudentStatus ledger row inside the
  surrounding transaction so the denormalisation and the ledger stay
  consistent.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias Intellispark.Students.StudentStatus

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.force_change_attribute(:current_status_id, nil)
    |> Ash.Changeset.after_action(fn _changeset, student ->
      tenant = student.school_id

      StudentStatus
      |> Ash.Query.filter(student_id == ^student.id and is_nil(cleared_at))
      |> Ash.Query.set_tenant(tenant)
      |> Ash.read!(authorize?: false)
      |> Enum.each(fn row ->
        Ash.update!(row, %{}, action: :clear, tenant: tenant, authorize?: false)
      end)

      {:ok, student}
    end)
  end
end
