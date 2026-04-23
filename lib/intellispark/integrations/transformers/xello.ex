defmodule Intellispark.Integrations.Transformers.Xello do
  @moduledoc "Xello transformer — Xello ingests via webhook, not batch sync. Stub that returns empty."
  @behaviour Intellispark.Integrations.Transformer

  @impl true
  def transform_students(_payload, _provider), do: {:ok, []}

  @impl true
  def transform_rosters(_payload, _provider), do: {:ok, []}
end
