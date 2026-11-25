defmodule Oaks.Repo.Migrations.AddObanJobs do
  use Ecto.Migration

  # Oban's job table, for durable background work (species photo imports and
  # storage cleanup, Oaks.Images). Later Oban upgrades need their own
  # versioned migrations (Oban.Migrations.up(version: N)), so rolling one back
  # doesn't drop this table.
  def up, do: Oban.Migrations.up()

  def down, do: Oban.Migrations.down()
end
