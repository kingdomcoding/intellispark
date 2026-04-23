defmodule Intellispark.Accounts.Oban.DailyDemoResetWorker do
  use Oban.Worker, queue: :default

  alias Intellispark.Accounts.DemoReset

  @impl Oban.Worker
  def perform(_job) do
    _log = DemoReset.run_daily()
    :ok
  end
end
