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

  def seed do
    load_app()
    {:ok, _} = Application.ensure_all_started(@app)
    seed_file = Path.join(:code.priv_dir(@app), "repo/seeds.exs")

    if File.exists?(seed_file) do
      Code.eval_file(seed_file)
    else
      raise "seed file not found: #{seed_file}"
    end
  end

  def create_admin(email, password) do
    load_app()
    {:ok, _} = Application.ensure_all_started(@app)

    Intellispark.Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: password,
      password_confirmation: password
    })
    |> Ash.create!(authorize?: false)
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)

  defp load_app, do: Application.load(@app)
end
