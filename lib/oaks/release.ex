defmodule Oaks.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :oaks

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc """
  Returns how many migrations have not been run yet, across all repos.

  `docker-entrypoint.sh` uses this to take a pre-migration backup only when
  there is something to migrate.
  """
  @spec pending_migration_count() :: non_neg_integer()
  def pending_migration_count do
    load_app()

    for repo <- repos(), reduce: 0 do
      count ->
        {:ok, pending, _} =
          Ecto.Migrator.with_repo(repo, fn repo ->
            repo |> Ecto.Migrator.migrations() |> Enum.count(&match?({:down, _, _}, &1))
          end)

        count + pending
    end
  end

  @doc """
  Prints a one-time setup link for the editor with `email`, creating the
  account if there is none. The link is valid for 15 minutes.

  Opening it sets a new password and authenticator app and shows new
  recovery codes, so this is also how to recover an account. Run it in the
  running app, so the password never passes through a shell:

      fly ssh console --app oaks -C "/app/bin/oaks rpc 'Oaks.Release.setup_link(\"you@example.com\")'"

  Locally: `mix run -e 'Oaks.Release.setup_link("you@example.com")'`.
  """
  @spec setup_link(String.t()) :: :ok | {:error, Ecto.Changeset.t()}
  def setup_link(email) when is_binary(email) do
    case Oaks.Accounts.create_setup_link(email) do
      {:ok, user, token} ->
        IO.puts("""
        Setup link for #{user.email} (valid for 15 minutes, works once):

          #{OaksWeb.Endpoint.url()}/users/setup/#{token}
        """)

      {:error, changeset} ->
        IO.puts(:stderr, "Could not create a setup link: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
