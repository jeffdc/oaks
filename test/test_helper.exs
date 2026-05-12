# SQLite is single-writer. We enforce serial execution across all test files
# (max_cases: 1) so concurrent test cases never race on the shared sandbox
# connection. Per-file async is independently blocked by DataCase.
ExUnit.start(max_cases: 1)
Ecto.Adapters.SQL.Sandbox.mode(Oaks.Repo, :manual)
