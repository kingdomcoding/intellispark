defmodule Intellispark.Support.Changes.PrefillFromIntervention do
  @moduledoc false
  use Ash.Resource.Change

  alias Intellispark.Support.InterventionLibraryItem

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, :intervention_library_item_id) do
      nil ->
        changeset

      id ->
        tenant = changeset.tenant

        case Ash.get(InterventionLibraryItem, id, tenant: tenant, authorize?: false) do
          {:ok, item} -> apply_prefill(changeset, item)
          {:error, _} -> Ash.Changeset.add_error(changeset, field: :intervention_library_item_id, message: "not found")
        end
    end
  end

  defp apply_prefill(changeset, item) do
    changeset
    |> Ash.Changeset.force_change_attribute(:intervention_library_item_id, item.id)
    |> maybe_set(:title, item.title)
    |> maybe_set(:description, item.description)
    |> maybe_set_ends_at(item.default_duration_days)
  end

  defp maybe_set(changeset, _field, nil), do: changeset

  defp maybe_set(changeset, field, default_value) do
    case Ash.Changeset.get_attribute(changeset, field) do
      nil -> Ash.Changeset.force_change_attribute(changeset, field, default_value)
      "" -> Ash.Changeset.force_change_attribute(changeset, field, default_value)
      _ -> changeset
    end
  end

  defp maybe_set_ends_at(changeset, nil), do: changeset

  defp maybe_set_ends_at(changeset, days) do
    case Ash.Changeset.get_attribute(changeset, :ends_at) do
      nil ->
        starts_at = Ash.Changeset.get_attribute(changeset, :starts_at) || Date.utc_today()
        Ash.Changeset.force_change_attribute(changeset, :ends_at, Date.add(starts_at, days))

      _ ->
        changeset
    end
  end
end
