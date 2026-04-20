defmodule Intellispark.Flags.Changes.SyncAssignments do
  @moduledoc """
  Reconciles FlagAssignment rows with the :assignee_ids argument: creates
  missing rows, clears (cleared_at) rows no longer in the list. Runs as an
  after_action inside the surrounding transaction.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias Intellispark.Flags.FlagAssignment

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _cs, flag ->
      ids = Ash.Changeset.get_argument(changeset, :assignee_ids) || []
      tenant = flag.school_id

      {:ok, existing} =
        FlagAssignment
        |> Ash.Query.filter(flag_id == ^flag.id and is_nil(cleared_at))
        |> Ash.Query.set_tenant(tenant)
        |> Ash.read(authorize?: false)

      existing_ids = Enum.map(existing, & &1.user_id)

      for uid <- ids -- existing_ids do
        case Ash.create(
               FlagAssignment,
               %{flag_id: flag.id, user_id: uid},
               tenant: tenant,
               actor: context.actor,
               authorize?: false
             ) do
          {:ok, _row} ->
            :ok

          {:error, %{errors: [%{private_vars: vars} | _]}} ->
            # Restore a previously cleared assignment via update rather than
            # tripping the unique index on (flag_id, user_id).
            if Keyword.get(vars || [], :constraint_type) == :unique do
              reactivate_assignment(flag.id, uid, tenant)
            else
              :ok
            end
        end
      end

      for row <- Enum.filter(existing, &(&1.user_id not in ids)) do
        {:ok, _} =
          Ash.update(row, %{}, action: :clear, tenant: tenant, authorize?: false)
      end

      {:ok, flag}
    end)
  end

  defp reactivate_assignment(flag_id, user_id, tenant) do
    case FlagAssignment
         |> Ash.Query.filter(flag_id == ^flag_id and user_id == ^user_id)
         |> Ash.Query.set_tenant(tenant)
         |> Ash.read_one(authorize?: false) do
      {:ok, %FlagAssignment{} = row} ->
        Ash.update!(row, %{}, action: :reactivate, tenant: tenant, authorize?: false)
        :ok

      _ ->
        :ok
    end
  end
end
