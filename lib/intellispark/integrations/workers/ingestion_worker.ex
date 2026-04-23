defmodule Intellispark.Integrations.Workers.IngestionWorker do
  @moduledoc """
  Per-sync-run ingestion worker. Loads the provider, calls its
  transformer to normalize payloads, bulk-upserts via
  `Student.:upsert_from_sis`, records per-record failures, and
  transitions the sync run's state-machine to its terminal state.
  """

  use Oban.Worker, queue: :ingestion, max_attempts: 3

  alias Intellispark.Integrations
  alias Intellispark.Integrations.{IntegrationProvider, IntegrationSyncRun, Transformer}
  alias Intellispark.Students.Student

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"sync_run_id" => sync_run_id, "school_id" => school_id}}) do
    run =
      Ash.get!(IntegrationSyncRun, sync_run_id, tenant: school_id, authorize?: false)

    provider =
      Ash.get!(IntegrationProvider, run.provider_id, tenant: school_id, authorize?: false)

    {:ok, run} = Ash.update(run, %{}, action: :start, tenant: school_id, authorize?: false)

    transformer = Transformer.for_provider(provider.provider_type)

    with {:ok, raw} <- fetch_payloads(provider),
         {:ok, payloads} <- transformer.transform_students(raw, provider) do
      result = bulk_upsert(payloads, school_id, run)
      finalize(run, school_id, result)
    else
      {:error, reason} ->
        Ash.update!(run, %{records_failed: 0},
          action: :fail,
          tenant: school_id,
          authorize?: false
        )

        {:error, inspect(reason)}
    end
  end

  defp fetch_payloads(%{provider_type: :csv, credentials: %{"csv_blob" => blob}})
       when is_binary(blob),
       do: {:ok, blob}

  defp fetch_payloads(%{provider_type: :csv}), do: {:ok, ""}
  defp fetch_payloads(_), do: {:ok, []}

  defp bulk_upsert([], _school_id, _run),
    do: %{processed: 0, created: 0, updated: 0, failed: 0}

  defp bulk_upsert(payloads, school_id, run) do
    stripped = Enum.map(payloads, &Map.drop(&1, [:school_id]))

    result =
      Ash.bulk_create(
        stripped,
        Student,
        :upsert_from_sis,
        return_records?: true,
        return_errors?: true,
        stop_on_error?: false,
        tenant: school_id,
        authorize?: false
      )

    records = result.records || []
    errors = result.errors || []

    Enum.each(errors, fn err ->
      raw = get_error_input(err)
      msg = format_error(err)

      Integrations.record_sync_error(
        %{
          sync_run_id: run.id,
          raw_payload: raw,
          error_message: msg,
          error_kind: :validation
        },
        tenant: school_id,
        authorize?: false
      )
    end)

    {created, updated} =
      Enum.reduce(records, {0, 0}, fn r, {c, u} ->
        if r.inserted_at == r.updated_at, do: {c + 1, u}, else: {c, u + 1}
      end)

    %{
      processed: length(payloads),
      created: created,
      updated: updated,
      failed: length(errors)
    }
  end

  defp finalize(run, school_id, %{processed: p, created: c, updated: u, failed: 0}) do
    Ash.update!(run, %{records_processed: p, records_created: c, records_updated: u},
      action: :succeed,
      tenant: school_id,
      authorize?: false
    )

    :ok
  end

  defp finalize(run, school_id, %{processed: p, created: c, updated: u, failed: f}) do
    Ash.update!(
      run,
      %{records_processed: p, records_created: c, records_updated: u, records_failed: f},
      action: :partial_succeed,
      tenant: school_id,
      authorize?: false
    )

    :ok
  end

  defp get_error_input(%{changeset: %Ash.Changeset{params: params}}) when is_map(params),
    do: params

  defp get_error_input(%{input: input}) when is_map(input), do: input
  defp get_error_input(_), do: %{}

  defp format_error(%{errors: errors}) when is_list(errors) and errors != [] do
    errors
    |> Enum.map(&format_single_error/1)
    |> Enum.uniq()
    |> Enum.join("; ")
  end

  defp format_error(err) when is_exception(err), do: Exception.message(err)
  defp format_error(err), do: inspect(err)

  defp format_single_error(%{field: field, message: message})
       when is_atom(field) and is_binary(message),
       do: "#{field}: #{message}"

  defp format_single_error(%{field: field}) when is_atom(field),
    do: "#{field}: is invalid"

  defp format_single_error(err) when is_exception(err), do: Exception.message(err)
  defp format_single_error(err), do: inspect(err)
end
