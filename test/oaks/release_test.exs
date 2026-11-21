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

  describe "setup_link/1" do
    import ExUnit.CaptureIO

    test "prints a working one-time link for a new or existing user" do
      output = capture_io(fn -> assert Release.setup_link("editor@example.com") == :ok end)

      assert output =~ "Setup link for editor@example.com"
      [_, token] = Regex.run(~r{/users/setup/([A-Za-z0-9_-]+)}, output)
      assert Oaks.Accounts.get_user_by_setup_token(token).email == "editor@example.com"
    end

    test "reports a bad email" do
      output =
        capture_io(:stderr, fn ->
          assert {:error, _} = Release.setup_link("not an email")
        end)

      assert output =~ "Could not create a setup link"
    end
  end
end
