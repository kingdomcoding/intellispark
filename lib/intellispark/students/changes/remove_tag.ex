defmodule Intellispark.Students.Changes.RemoveTag do
  @moduledoc """
  Called by Student.remove_tag/3. Destroys the StudentTag join row for the
  given (student_id, tag_id) pair inside the action's transaction. Silent
  no-op if the tag isn't applied — the UI's outcome is "the tag is gone",
  whether it was gone already or not.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias Intellispark.Students.StudentTag

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, student ->
      tag_id = Ash.Changeset.get_argument(changeset, :tag_id)
      tenant = student.school_id

      StudentTag
      |> Ash.Query.filter(student_id == ^student.id and tag_id == ^tag_id)
      |> Ash.Query.set_tenant(tenant)
      |> Ash.read!(authorize?: false)
      |> Enum.each(fn row ->
        Ash.destroy!(row, actor: context.actor, tenant: tenant, authorize?: false)
      end)

      {:ok, student}
    end)
  end
end
