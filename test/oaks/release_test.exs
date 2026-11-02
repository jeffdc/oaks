defmodule Oaks.ReleaseTest do
  use Oaks.DataCase

  alias Oaks.Release

  test "counts no pending migrations on a migrated database" do
    assert Release.pending_migration_count() == 0
  end

  test "counts a migration that hasn't run" do
    Oaks.Repo.query!("DELETE FROM schema_migrations WHERE version = 20261102190000")

    assert Release.pending_migration_count() == 1
  end
end
