defmodule Intellispark.ReleaseTest do
  use ExUnit.Case, async: true

  alias Intellispark.Release

  describe "migrate/0" do
    test "is exported and targets every configured repo" do
      Code.ensure_loaded!(Release)
      assert function_exported?(Release, :migrate, 0)

      repos = Application.fetch_env!(:intellispark, :ecto_repos)
      assert Intellispark.Repo in repos
      assert length(repos) >= 1
    end
  end

  describe "seed/0" do
    test "is exported and resolves the repo seed file path via :code.priv_dir/1" do
      Code.ensure_loaded!(Release)
      assert function_exported?(Release, :seed, 0)

      seed_file = Path.join(:code.priv_dir(:intellispark), "repo/seeds.exs")

      assert File.exists?(seed_file),
             "expected seed file at #{seed_file} — release seed/0 relies on this path"
    end
  end
end
