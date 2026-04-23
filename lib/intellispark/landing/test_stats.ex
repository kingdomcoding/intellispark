defmodule Intellispark.Landing.TestStats do
  @moduledoc """
  Reads `priv/test_stats.json` — committed back to main by the CI
  workflow after every green test run. Graceful zero-fallback when
  the file is missing (first-deploy + dev before local seed).
  """

  @default %{"passing" => 0, "failing" => 0, "properties" => 0, "commit_sha" => "unknown"}

  def read do
    path = Path.join(:code.priv_dir(:intellispark), "test_stats.json")

    case File.read(path) do
      {:ok, bin} ->
        case Jason.decode(bin) do
          {:ok, map} -> Map.merge(@default, map)
          _ -> @default
        end

      _ ->
        @default
    end
  end

  def passing, do: read()["passing"]
  def failing, do: read()["failing"]
end
