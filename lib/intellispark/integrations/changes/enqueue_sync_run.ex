defmodule Intellispark.Integrations.Changes.EnqueueSyncRun do
  @moduledoc """
  After-action change that creates a `:pending` SyncRun for the
  provider + inserts an `IngestionWorker` Oban job. Used by both the
  AshOban cron trigger and the manual `:run_now` generic action.
  """

  use Ash.Resource.Change

  alias Intellispark.Integrations.IntegrationSyncRun
  alias Intellispark.Integrations.Workers.IngestionWorker

  @impl true
  def change(changeset, opts, _context) do
    trigger_source = Keyword.get(opts, :trigger_source, :manual)

    Ash.Changeset.after_action(changeset, fn _cs, provider ->
      {:ok, run} =
        Ash.create(
          IntegrationSyncRun,
          %{provider_id: provider.id, trigger_source: trigger_source},
          tenant: provider.school_id,
          authorize?: false
        )

      {:ok, _job} =
        IngestionWorker.new(%{
          sync_run_id: run.id,
          school_id: provider.school_id
        })
        |> Oban.insert()

      {:ok, provider}
    end)
  end
end
