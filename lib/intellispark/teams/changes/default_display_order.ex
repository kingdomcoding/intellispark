defmodule Intellispark.Teams.Changes.DefaultDisplayOrder do
  @moduledoc false
  use Ash.Resource.Change

  require Ash.Query

  alias Intellispark.Teams.Strength

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :display_order) do
      nil -> set_max_plus_one(changeset)
      0 -> set_max_plus_one(changeset)
      _ -> changeset
    end
  end

  defp set_max_plus_one(changeset) do
    student_id = Ash.Changeset.get_attribute(changeset, :student_id)
    school_id = Ash.Changeset.get_attribute(changeset, :school_id) || changeset.tenant

    max_existing =
      Strength
      |> Ash.Query.filter(student_id == ^student_id)
      |> Ash.Query.set_tenant(school_id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.display_order)
      |> Enum.max(fn -> 0 end)

    Ash.Changeset.force_change_attribute(changeset, :display_order, max_existing + 1)
  end
end
