defmodule Intellispark.Integrations.Transformer do
  @moduledoc """
  Transformer plugins normalize provider-specific payloads to canonical
  maps consumed by `Student.:upsert_from_sis`. Each provider type has
  a corresponding transformer module; `for_provider/1` dispatches by
  atom.
  """

  @callback transform_students(any(), map()) :: {:ok, [map()]} | {:error, String.t()}
  @callback transform_rosters(any(), map()) :: {:ok, [map()]} | {:error, String.t()}

  def for_provider(:csv), do: Intellispark.Integrations.Transformers.Csv
  def for_provider(:oneroster), do: Intellispark.Integrations.Transformers.OneRoster
  def for_provider(:clever), do: Intellispark.Integrations.Transformers.Clever
  def for_provider(:classlink), do: Intellispark.Integrations.Transformers.ClassLink
  def for_provider(:xello), do: Intellispark.Integrations.Transformers.Xello
  def for_provider(:custom), do: Intellispark.Integrations.Transformers.Custom
end
