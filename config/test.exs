import Config

# Only in tests, make password hashing cheap
config :argon2_elixir, t_cost: 1, m_cost: 8

config :oaks, env: :test

# Configure your database
# Use a separate test database (no production data)
config :oaks, Oaks.Repo,
  database: Path.expand("../priv/oaks_test.sqlite", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox,
  # WAL for better concurrency — allows reads during write transactions
  journal_mode: :wal,
  busy_timeout: 5000,
  default_transaction_mode: :immediate

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :oaks, OaksWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "+Qd/R+G2s0urapTtIRzFrlNgnqQPVTj60qH0NEBTRWJTKocUUEnLIJ/z+6n6zFtk",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Fixed, non-secret login encryption key (see config/runtime.exs)
config :oaks, :login_encryption_key, "dGVzdC1sb2dpbi1lbmNyeXB0aW9uLWtleS0zMmJ5dGU="

# Login rate limits high enough that the suite's own logins never trip them;
# the rate-limit tests lower them.
config :oaks, :login_rate_limits, per_ip: 1_000, per_account: 1_000
config :oaks, :api_token_rate_limits, per_token: 1_000, failures_per_ip: 1_000

# Compile the dev-only routes (the one-click dev login) so they can be tested.
config :oaks, dev_routes: true

# Record page views inline so no analytics insert outlives its test.
config :oaks, :analytics_async, false

# Tests call Oaks.Analytics.Rollup directly instead of on a timer.
config :oaks, Oaks.Analytics.RollupScheduler, enabled: false

# No pauses between rollup days/batches, and tiny prune batches so the loop runs.
config :oaks, Oaks.Analytics.Rollup, pause_ms: 0, prune_batch: 2
