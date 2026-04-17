defmodule Intellispark.DataCase do
  @moduledoc """
  Test case template for tests that touch the database via Ash. Sets up an
  Ecto Sandbox so changes are rolled back after each test.

  Use `async: false` if your test uses non-sandbox-aware processes (eg the
  endpoint).
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Intellispark.DataCase
    end
  end

  setup tags do
    Intellispark.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Intellispark.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
