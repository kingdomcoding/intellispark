defmodule Intellispark.Students.Changes.SetStudentStatus do
  @moduledoc """
  Called by Student.set_status/3. Closes out any active StudentStatus row
  (filter `cleared_at is_nil`), creates a new active row for the given
  status_id, and denormalises current_status_id onto the Student.

  All three mutations happen inside the action's wrapping transaction; a
  failure anywhere rolls back cleanly.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias Intellispark.Students.StudentStatus

  @impl true
  def change(changeset, _opts, context) do
    status_id = Ash.Changeset.get_argument(changeset, :status_id)
    actor = context.actor
    tenant = changeset.tenant || Ash.Changeset.get_attribute(changeset, :school_id)

    changeset
    |> Ash.Changeset.force_change_attribute(:current_status_id, status_id)
    |> Ash.Changeset.after_action(fn _changeset, student ->
      close_active_statuses(student, tenant, actor)
      open_new_status(student, status_id, tenant, actor)
      {:ok, student}
    end)
  end

  defp close_active_statuses(student, tenant, _actor) do
    StudentStatus
    |> Ash.Query.filter(student_id == ^student.id and is_nil(cleared_at))
    |> Ash.Query.set_tenant(tenant)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn row ->
      Ash.update!(row, %{}, action: :clear, tenant: tenant, authorize?: false)
    end)
  end

  defp open_new_status(student, status_id, tenant, actor) do
    Ash.create!(
      StudentStatus,
      %{student_id: student.id, status_id: status_id},
      actor: actor,
      tenant: tenant,
      authorize?: false
    )
  end
end
