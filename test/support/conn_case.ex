defmodule OaksWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test.

  NOTE: This project uses SQLite which does NOT support `async: true`.
  All tests run serially (enforced by `max_cases: 1` in test_helper.exs
  and a runtime guard in `Oaks.DataCase`).
  """

  use ExUnit.CaseTemplate

  alias Oaks.Accounts.Scope
  alias Oaks.AccountsFixtures

  using do
    quote do
      # The default endpoint for testing
      @endpoint OaksWeb.Endpoint

      use OaksWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import OaksWeb.ConnCase
    end
  end

  setup tags do
    Oaks.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that creates a set-up user and logs them in:

      setup :register_and_log_in_user

  Adds `:conn` (logged in), `:user` and `:scope` to the test context. Tag a
  test with `token_authenticated_at: dt` to set when the login happened.
  """
  def register_and_log_in_user(%{conn: conn} = context) do
    user = AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)
    opts = context |> Map.take([:token_authenticated_at]) |> Enum.into([])

    %{conn: log_in_user(conn, user, opts), user: user, scope: scope}
  end

  @doc """
  Logs `user` into `conn` by putting a session token in its session, as a
  completed login does. LiveViews mounted from the conn see `@current_scope`.
  """
  def log_in_user(conn, user, opts \\ []) do
    token = Oaks.Accounts.generate_user_session_token(user)

    if authenticated_at = opts[:token_authenticated_at] do
      AccountsFixtures.override_token_authenticated_at(token, authenticated_at)
    end

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end
end
