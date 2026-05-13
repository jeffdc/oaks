import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/oaks start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :oaks, OaksWeb.Endpoint, server: true
end

# Load API key for authentication.
# - prod: OAK_API_KEY env var only. If missing, log a loud warning to stderr
#   and leave the key unset — the app still boots and serves read traffic,
#   but every write/auth request will be rejected until the secret is set.
#   The `~/.oak/api_key` fallback is intentionally not consulted in prod:
#   it can never exist inside the Fly container, and previously masked a
#   missing-secret outage as a generic "invalid key" message.
# - dev: env var, then ~/.oak/api_key fallback for local convenience.
# - test: skipped here; test.exs sets a known test key.
case config_env() do
  :test ->
    :ok

  :prod ->
    case System.get_env("OAK_API_KEY") do
      key when is_binary(key) and key != "" ->
        config :oaks, :api_key, key

      _ ->
        IO.puts(
          :stderr,
          "WARNING: OAK_API_KEY is not set. API authentication will reject every request. " <>
            "Set it with: fly secrets set OAK_API_KEY=<key> --app oaks"
        )

        config :oaks, :api_key, nil
    end

  _ ->
    config :oaks, :api_key, OaksWeb.Plugs.Auth.load_api_key()
end

# Only override port if PORT env var is explicitly set (don't interfere with test config)
if port = System.get_env("PORT") do
  config :oaks, OaksWeb.Endpoint, http: [port: String.to_integer(port)]
end

if config_env() == :prod do
  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /data/oaks.db
      """

  config :oaks, Oaks.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    busy_timeout: 10_000

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :oaks, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :oaks, OaksWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    check_origin: [
      "https://#{host}",
      "https://oakcompendium.org",
      "https://oakcompendium.com",
      "https://www.oakcompendium.org",
      "https://www.oakcompendium.com",
      "https://api.oakcompendium.org",
      "https://api.oakcompendium.com"
    ],
    http: [
      # Enable IPv6 and bind on all interfaces.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: secret_key_base
end
