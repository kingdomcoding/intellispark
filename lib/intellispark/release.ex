defmodule Intellispark.Release do
  @moduledoc """
  Helpers for tasks that run inside a compiled release, where Mix is unavailable.
  Invoked by the runtime Dockerfile's CMD on container start, so migrations apply
  automatically before the BEAM endpoint begins serving traffic.
  """
  @app :intellispark

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)

  defp load_app, do: Application.load(@app)
end
