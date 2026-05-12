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
end
