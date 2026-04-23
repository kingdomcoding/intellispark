defmodule Intellispark.Integrations.IntegrationSyncRunTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures

  alias Intellispark.Integrations
  alias Intellispark.Integrations.IntegrationSyncRun

  setup do
    world = setup_world()

    {:ok, provider} =
      Integrations.create_provider(
        %{provider_type: :csv, name: "Test"},
        tenant: world.school.id,
        authorize?: false
      )

    {:ok, Map.put(world, :provider, provider)}
  end

  defp create_run(%{school: school, provider: provider}) do
    {:ok, run} =
      Ash.create(IntegrationSyncRun, %{provider_id: provider.id, trigger_source: :manual},
        tenant: school.id,
        authorize?: false
      )

    run
  end

  test "initial state is :pending", ctx do
    run = create_run(ctx)
    assert run.status == :pending
  end

  test ":start transitions to :running + stamps started_at", ctx do
    run = create_run(ctx)

    {:ok, started} =
      Ash.update(run, %{}, action: :start, tenant: ctx.school.id, authorize?: false)

    assert started.status == :running
    assert started.started_at != nil
  end

  test ":succeed transitions running -> succeeded + stamps completed_at", ctx do
    run = create_run(ctx)

    {:ok, started} =
      Ash.update(run, %{}, action: :start, tenant: ctx.school.id, authorize?: false)

    {:ok, done} =
      Ash.update(
        started,
        %{records_processed: 5, records_created: 3, records_updated: 2},
        action: :succeed,
        tenant: ctx.school.id,
        authorize?: false
      )

    assert done.status == :succeeded
    assert done.completed_at != nil
    assert done.records_processed == 5
  end

  test ":partial_succeed path", ctx do
    run = create_run(ctx)

    {:ok, started} =
      Ash.update(run, %{}, action: :start, tenant: ctx.school.id, authorize?: false)

    {:ok, done} =
      Ash.update(
        started,
        %{records_processed: 3, records_created: 2, records_updated: 0, records_failed: 1},
        action: :partial_succeed,
        tenant: ctx.school.id,
        authorize?: false
      )

    assert done.status == :partially_succeeded
    assert done.records_failed == 1
  end

  test "invalid transition (:succeed from :succeeded) rejected", ctx do
    run = create_run(ctx)

    {:ok, started} =
      Ash.update(run, %{}, action: :start, tenant: ctx.school.id, authorize?: false)

    {:ok, done} =
      Ash.update(started, %{records_processed: 0, records_created: 0, records_updated: 0},
        action: :succeed,
        tenant: ctx.school.id,
        authorize?: false
      )

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.update(done, %{records_processed: 0, records_created: 0, records_updated: 0},
               action: :succeed,
               tenant: ctx.school.id,
               authorize?: false
             )
  end
end
