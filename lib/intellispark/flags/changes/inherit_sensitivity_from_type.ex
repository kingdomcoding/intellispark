defmodule Intellispark.Flags.Changes.InheritSensitivityFromType do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :sensitive?) do
      nil ->
        maybe_inherit(changeset)

      _explicit ->
        changeset
    end
  end

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
