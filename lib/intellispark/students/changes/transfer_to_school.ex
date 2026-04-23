defmodule Intellispark.Students.Changes.TransferToSchool do
  @moduledoc """
  Called by Student.transfer/3. Archives the source student and creates a
  matching row in the destination school inside one transaction. Both commit
  or both roll back. Downstream rows (flags, high-5s, supports, notes, team
  memberships, key connections, strengths, survey assignments) are not
  migrated — they stay at the source for audit integrity.
  """

  use Ash.Resource.Change

  alias Intellispark.Students.Student

  @impl true
  def change(changeset, _opts, context) do
    dest_id = Ash.Changeset.get_argument(changeset, :destination_school_id)

    changeset
    |> Ash.Changeset.change_attribute(:archived_at, DateTime.utc_now())
    |> Ash.Changeset.after_action(fn _changeset, source ->
      attrs = %{
        first_name: source.first_name,
        last_name: source.last_name,
        preferred_name: source.preferred_name,
        date_of_birth: source.date_of_birth,
        grade_level: source.grade_level,
        enrollment_status: :active,
        external_id: source.external_id,
        email: source.email,
        phone: source.phone,
        gender: source.gender,
        ethnicity_race: source.ethnicity_race
      }

      case Ash.create(Student, attrs,
             action: :create,
             tenant: dest_id,
             actor: context.actor
           ) do
        {:ok, _created} -> {:ok, source}
        {:error, error} -> {:error, error}
      end
    end)
  end
end
