import Config

config :oak_compendium, env: :test

# Configure your database
# Use a separate test database (no production data)
config :oak_compendium, OakCompendium.Repo,
  database: Path.expand("../priv/oak_compendium_test.sqlite", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox,
  # WAL for better concurrency — allows reads during write transactions
  journal_mode: :wal,
  busy_timeout: 5000

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :oak_compendium, OakCompendiumWeb.Endpoint,
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

# Test API key for auth tests
config :oak_compendium, :api_key, "test-api-key-secret"
