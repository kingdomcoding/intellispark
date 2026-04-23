defmodule Intellispark.Integrations.Changes.StampSyncFinished do
  @moduledoc """
  Stamps `last_synced_at` + the per-status `last_success_at` /
  `last_failure_at` on `IntegrationProvider` after a sync run
  terminates. Triggered from `IntegrationSyncRun` state-machine
  transitions.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    now = DateTime.utc_now()
    status = Ash.Changeset.get_argument(changeset, :status)

    changeset
    |> Ash.Changeset.force_change_attribute(:last_synced_at, now)
    |> stamp_status(status, now)
  end

  defp stamp_status(changeset, :succeeded, now),
    do: Ash.Changeset.force_change_attribute(changeset, :last_success_at, now)

  defp stamp_status(changeset, :partially_succeeded, now),
    do: Ash.Changeset.force_change_attribute(changeset, :last_success_at, now)

  defp stamp_status(changeset, :failed, now),
    do: Ash.Changeset.force_change_attribute(changeset, :last_failure_at, now)

  defp stamp_status(changeset, _other, _now), do: changeset
end
