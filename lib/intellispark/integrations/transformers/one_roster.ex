defmodule Intellispark.Integrations.Transformers.OneRoster do
  @moduledoc "OneRoster 1.2 REST transformer — stubbed in Phase 11. Full implementation in a future phase."
  @behaviour Intellispark.Integrations.Transformer

  @impl true
  def transform_students(_payload, _provider), do: {:ok, []}

  @impl true
  def transform_rosters(_payload, _provider), do: {:ok, []}
end
