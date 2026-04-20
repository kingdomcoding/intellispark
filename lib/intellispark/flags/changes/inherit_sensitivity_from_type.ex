defmodule Intellispark.Flags.Changes.InheritSensitivityFromType do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    if explicitly_provided?(changeset) do
      changeset
    else
      maybe_inherit(changeset)
    end
  end

  defp explicitly_provided?(%{params: params}) when is_map(params) do
    Map.has_key?(params, "sensitive?") or Map.has_key?(params, :sensitive?)
  end

  defp explicitly_provided?(_), do: false

  defp maybe_inherit(changeset) do
    type_id = Ash.Changeset.get_attribute(changeset, :flag_type_id)
    tenant = changeset.tenant || Ash.Changeset.get_attribute(changeset, :school_id)

    if type_id && tenant do
      case Ash.get(Intellispark.Flags.FlagType, type_id, tenant: tenant, authorize?: false) do
        {:ok, type} ->
          Ash.Changeset.force_change_attribute(changeset, :sensitive?, type.default_sensitive?)

        _ ->
          changeset
      end
    else
      changeset
    end
  end
end
