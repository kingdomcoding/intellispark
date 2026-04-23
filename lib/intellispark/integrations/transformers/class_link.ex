defmodule Intellispark.Integrations.Transformers.ClassLink do
  @moduledoc "ClassLink OneRoster transformer — stubbed in Phase 11."
  @behaviour Intellispark.Integrations.Transformer

  @impl true
  def transform_students(_payload, _provider), do: {:ok, []}

  @impl true
  def transform_rosters(_payload, _provider), do: {:ok, []}
end
