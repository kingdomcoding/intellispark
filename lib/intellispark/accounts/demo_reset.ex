defmodule Intellispark.Accounts.DemoReset do
  @moduledoc """
  Daily cron task that destroys expired `DemoSession` rows and records
  a `DemoResetLog` entry. Scope is deliberately narrow — only session
  cleanup, not broader content wipe. Seeded baseline data stays; if a
  demo admin vandalizes student rows, reseed with
  `/app/bin/intellispark rpc 'Intellispark.Release.seed()'`.
  """

  require Ash.Query

  alias Intellispark.Accounts.{DemoResetLog, DemoSession}

  def run_daily do
    now = DateTime.utc_now()

    expired =
      DemoSession
      |> Ash.Query.filter(expires_at < ^now)
      |> Ash.read!(authorize?: false)

    Enum.each(expired, &Ash.destroy!(&1, authorize?: false))

    {:ok, log} =
      DemoResetLog
      |> Ash.Changeset.for_create(:create, %{
        sessions_destroyed: length(expired),
        ran_at: now
      })
      |> Ash.create(authorize?: false)

    log
  end
end
