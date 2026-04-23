defmodule Intellispark.Integrations.Transformers.Custom do
  @moduledoc "Escape hatch for ad-hoc integrations — stubbed in Phase 11."
  @behaviour Intellispark.Integrations.Transformer

  @impl true
  def transform_students(_payload, _provider), do: {:ok, []}

  @impl true
  def transform_rosters(_payload, _provider), do: {:ok, []}
end
