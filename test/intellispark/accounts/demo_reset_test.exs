defmodule Intellispark.Accounts.DemoResetTest do
  use Intellispark.DataCase, async: false

  require Ash.Query
  import Intellispark.StudentsFixtures

  alias Intellispark.Accounts.{DemoReset, DemoResetLog, DemoSession}

  describe "run_daily/0" do
    test "destroys expired DemoSession rows" do
      %{admin: admin} = setup_world()

      {:ok, expired} =
        DemoSession
        |> Ash.Changeset.for_create(:create, %{
          persona: :district_admin,
          user_id: admin.id,
          ip_hash: "expired-ip",
          user_agent_hash: "expired-ua",
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        })
        |> Ash.create(authorize?: false)

      {:ok, fresh} =
        DemoSession
        |> Ash.Changeset.for_create(:create, %{
          persona: :counselor,
          user_id: admin.id,
          ip_hash: "fresh-ip",
          user_agent_hash: "fresh-ua",
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })
        |> Ash.create(authorize?: false)

      _log = DemoReset.run_daily()

      remaining =
        DemoSession
        |> Ash.Query.filter(id in [^expired.id, ^fresh.id])
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)

      refute expired.id in remaining
      assert fresh.id in remaining
    end

    test "writes a DemoResetLog row with the destroyed count" do
      %{admin: admin} = setup_world()

      {:ok, _} =
        DemoSession
        |> Ash.Changeset.for_create(:create, %{
          persona: :district_admin,
          user_id: admin.id,
          ip_hash: "x",
          user_agent_hash: "y",
          expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
        })
        |> Ash.create(authorize?: false)

      before = DemoResetLog |> Ash.read!(authorize?: false) |> length()

      log = DemoReset.run_daily()

      after_ = DemoResetLog |> Ash.read!(authorize?: false) |> length()

      assert after_ == before + 1
      assert log.sessions_destroyed >= 1
    end

    test "leaves non-expired DemoSession rows untouched and still emits a log" do
      %{admin: admin} = setup_world()

      {:ok, fresh} =
        DemoSession
        |> Ash.Changeset.for_create(:create, %{
          persona: :district_admin,
          user_id: admin.id,
          ip_hash: "x",
          user_agent_hash: "y",
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })
        |> Ash.create(authorize?: false)

      log = DemoReset.run_daily()

      assert {:ok, %DemoSession{}} = Ash.get(DemoSession, fresh.id, authorize?: false)
      assert log.sessions_destroyed == 0
    end
  end
end
