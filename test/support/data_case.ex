defmodule Oaks.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  NOTE: This project uses SQLite which does NOT support `async: true`.
  SQLite is single-writer, so concurrent tests holding write transactions
  will cause "Database busy" errors. Always use `async: false` (the default).
  """

  alias Ecto.Adapters.SQL.Sandbox

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Oaks.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Oaks.DataCase
    end
  end

  setup tags do
    Oaks.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    if tags[:async] do
      raise "async: true is not supported with SQLite. Use async: false (the default)."
    end

    pid = Sandbox.start_owner!(Oaks.Repo, shared: not tags[:async])

    on_exit(fn ->
      await_task_supervisor_children()
      Sandbox.stop_owner(pid)
    end)
  end

  # Wait briefly for any in-flight fire-and-forget tasks (e.g., analytics
  # inserts via OaksWeb.Plugs.Analytics / OaksWeb.Analytics.TrackPageView)
  # to finish before the sandbox is torn down. Otherwise the tasks try to
  # use a checked-in connection and emit DBConnection.ConnectionError
  # warnings — and intermittently crash the suite with exit 139.
  defp await_task_supervisor_children do
    case Process.whereis(Oaks.TaskSupervisor) do
      nil ->
        :ok

      _pid ->
        Oaks.TaskSupervisor
        |> Task.Supervisor.children()
        |> Enum.each(fn child ->
          ref = Process.monitor(child)

          receive do
            {:DOWN, ^ref, :process, ^child, _reason} -> :ok
          after
            1_000 -> :ok
          end
        end)
    end
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
