defmodule Intellispark.Repo.Migrations.InstallOban do
  use Ecto.Migration

  def up do
    Oban.Migration.up(version: 13)
  end

  def down do
    Oban.Migration.down(version: 1)
  end
end
