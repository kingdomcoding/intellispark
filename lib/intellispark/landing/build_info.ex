defmodule Intellispark.Landing.BuildInfo do
  @moduledoc """
  Reads `priv/build_info.json` baked at Docker build time by
  `mix landing.record_build_info`. Cached in ETS with a 5-min TTL.
  """

  @table :landing_build_info
  @ttl_ms 5 * 60 * 1000

  def last_commit_short, do: Map.get(info(), "commit_short_sha", "unknown")
  def commit_subject, do: Map.get(info(), "commit_subject", "")
  def commit_timestamp, do: Map.get(info(), "commit_timestamp", 0)
  def phase_tags, do: Map.get(info(), "phase_tags", [])
  def adr_count, do: Map.get(info(), "adr_count", 0)
  def built_at, do: Map.get(info(), "built_at", 0)

  def info do
    ensure_table()
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, :info) do
      [{:info, data, expires_at}] when expires_at > now ->
        data

      _ ->
        data = load()
        :ets.insert(@table, {:info, data, now + @ttl_ms})
        data
    end
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, read_concurrency: true])

      _ ->
        :ok
    end
  end

  defp load do
    path = Path.join(:code.priv_dir(:intellispark), "build_info.json")

    case File.read(path) do
      {:ok, bin} ->
        case Jason.decode(bin) do
          {:ok, map} -> map
          _ -> %{}
        end

      _ ->
        %{}
    end
  end
end
