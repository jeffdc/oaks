import Config

config :oak_compendium, env: :dev

# Configure your database
# DATABASE_PATH env var overrides the default for flexibility
# Falls back to oak_compendium.db at the project root for normal development
config :oak_compendium, OakCompendium.Repo,
  database: System.get_env("DATABASE_PATH", Path.expand("../oak_compendium.db", __DIR__)),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  busy_timeout: 5000

# For development, we disable any cache and enable
# debugging and code reloading.
config :oak_compendium, OakCompendiumWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "CO4IP1iuO8Iz/4xLyABdOz0Chmlfkgx5UL1bx1XZpOdNPQ+PLZIO9ZFWgl23W3E8",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:oak_compendium, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:oak_compendium, ~w(--watch)]}
  ]

# Reload browser tabs when matching files change.
config :oak_compendium, OakCompendiumWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      # Static assets, except user uploads
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
      # Router, Controllers, LiveViews and LiveComponents
      ~r"lib/oak_compendium_web/router\.ex$",
      ~r"lib/oak_compendium_web/(controllers|live|components)/.*\.(ex|heex)$"
    ]
  ]

# Enable dev routes
config :oak_compendium, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include debug annotations and locations in rendered markup.
  # Changing this configuration will require mix clean and a full recompile.
  debug_heex_annotations: true,
  debug_attributes: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true
