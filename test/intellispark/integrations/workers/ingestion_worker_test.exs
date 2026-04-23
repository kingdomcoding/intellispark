defmodule Intellispark.Integrations.Workers.IngestionWorkerTest do
  use Intellispark.DataCase, async: false
  use Oban.Testing, repo: Intellispark.Repo

  import Intellispark.StudentsFixtures

  alias Intellispark.Integrations
  alias Intellispark.Integrations.Workers.IngestionWorker
  alias Intellispark.Students.Student

  setup do
    world = setup_world()

    {:ok, provider} =
      Integrations.create_provider(
        %{
          provider_type: :csv,
          name: "Test CSV",
          credentials: %{"csv_blob" => sample_csv()}
        },
        tenant: world.school.id,
        authorize?: false
      )

    {:ok, run} =
      Ash.create(
        Intellispark.Integrations.IntegrationSyncRun,
        %{provider_id: provider.id, trigger_source: :manual},
        tenant: world.school.id,
        authorize?: false
      )

    {:ok, Map.put(world, :provider, provider) |> Map.put(:run, run)}
  end

  test "happy path: 3 payloads upsert + run :succeeded", %{school: school, run: run} do
    assert :ok =
             IngestionWorker.perform(%Oban.Job{
               args: %{"sync_run_id" => run.id, "school_id" => school.id}
             })

    reloaded =
      Ash.get!(Intellispark.Integrations.IntegrationSyncRun, run.id,
        tenant: school.id,
        authorize?: false
      )

    assert reloaded.status == :succeeded
    assert reloaded.records_processed == 3
    assert reloaded.records_created == 3

    students = Ash.read!(Student, tenant: school.id, authorize?: false)
    assert length(students) == 3
  end

  test "partial: invalid payload → :partially_succeeded + error row",
       %{school: school, provider: provider} do
    {:ok, updated} =
      Integrations.update_provider_credentials(
        provider,
        %{credentials: %{"csv_blob" => csv_with_missing_field()}},
        tenant: school.id,
        authorize?: false
      )

    {:ok, run} =
      Ash.create(
        Intellispark.Integrations.IntegrationSyncRun,
        %{provider_id: updated.id, trigger_source: :manual},
        tenant: school.id,
        authorize?: false
      )

    assert :ok =
             IngestionWorker.perform(%Oban.Job{
               args: %{"sync_run_id" => run.id, "school_id" => school.id}
             })

    reloaded =
      Ash.get!(Intellispark.Integrations.IntegrationSyncRun, run.id,
        tenant: school.id,
        load: [:errors],
        authorize?: false
      )

    assert reloaded.status == :partially_succeeded
    assert reloaded.records_failed == 1
    assert length(reloaded.errors) == 1
  end

  defp sample_csv do
    """
    sourcedId,givenName,familyName,email,grades,status,gender,phone
    S001,Ada,Lovelace,ada@ex.com,9,active,F,555-0001
    S002,Alan,Turing,alan@ex.com,10,active,M,555-0002
    S003,Grace,Hopper,grace@ex.com,11,active,F,555-0003
    """
  end

  defp csv_with_missing_field do
    """
    sourcedId,givenName,familyName,email,grades,status,gender,phone
    S010,,Lovelace,bad@ex.com,9,active,F,555-0100
    S011,Good,Name,ok@ex.com,10,active,M,555-0101
    """
  end
end
