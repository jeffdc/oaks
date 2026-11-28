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

# Login encryption key (Oaks.Accounts.SecretBox): 32 bytes, base64. It
# encrypts TOTP secrets at rest. Create it with `openssl rand -base64 32` and
# set it with: fly secrets set LOGIN_ENCRYPTION_KEY=<key> --app oaks
# - prod: LOGIN_ENCRYPTION_KEY only. If missing or malformed, log a loud
#   warning and leave it unset: the site still serves read traffic, but
#   setting up and logging in fail until the secret is set. Changing the key
#   makes enrolled authenticator apps unusable; recover with a setup link.
# - dev and test: a fixed, non-secret key in dev.exs and test.exs.
if config_env() == :prod do
  key = System.get_env("LOGIN_ENCRYPTION_KEY", "")

  case Base.decode64(String.trim(key)) do
    {:ok, <<_::binary-32>>} ->
      config :oaks, :login_encryption_key, key

    _ ->
      IO.puts(
        :stderr,
        "WARNING: LOGIN_ENCRYPTION_KEY is missing or is not 32 bytes of base64. " <>
          "Logging in will fail. Set it with: " <>
          "fly secrets set LOGIN_ENCRYPTION_KEY=$(openssl rand -base64 32) --app oaks"
      )
  end
end

# Species photo storage (Oaks.Storage.Images). The oaks-images-upload user's
# keys (infra/README.md), set with:
#   fly secrets set IMAGES_AWS_ACCESS_KEY_ID=... IMAGES_AWS_SECRET_ACCESS_KEY=... --app oaks
# - prod: if they are missing, log a loud warning: the site still serves
#   photos (from the CDN), but importing and removing them fail.
# - dev: Local storage, unless IMAGES_STORAGE=s3 with the keys, which uses the
#   real bucket and CDN (to smoke-test Oaks.Storage.S3).
# - test: fixed in test.exs.
if config_env() != :test do
  key_id = System.get_env("IMAGES_AWS_ACCESS_KEY_ID", "")
  secret = System.get_env("IMAGES_AWS_SECRET_ACCESS_KEY", "")

  if key_id != "" and secret != "" do
    config :oaks, :images, access_key_id: key_id, secret_access_key: secret
  else
    if config_env() == :prod do
      IO.puts(
        :stderr,
        "WARNING: IMAGES_AWS_ACCESS_KEY_ID or IMAGES_AWS_SECRET_ACCESS_KEY is missing. " <>
          "Importing and removing species photos will fail. See infra/README.md."
      )
    end
  end

  if config_env() == :dev and System.get_env("IMAGES_STORAGE") == "s3" do
    config :oaks, :images,
      adapter: Oaks.Storage.S3,
      cdn_url: "https://images.oakcompendium.org"
  end
end

# Only override port if PORT env var is explicitly set (don't interfere with test config)
if port = System.get_env("PORT") do
  config :oaks, OaksWeb.Endpoint, http: [port: String.to_integer(port)]
end

if config_env() == :prod do
  # JSON log lines for Fly's log aggregation, with the request ID and the other
  # metadata. Dev and test keep the text format from config.exs. It must be set
  # here, not in prod.exs: LoggerJSON has to be compiled before its formatter
  # function can be called.
  config :logger, :default_handler, formatter: LoggerJSON.Formatters.Basic.new(metadata: :all)

  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /data/oaks.db
      """

  config :oaks, Oaks.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    busy_timeout: 10_000,
    # Take the write lock when a transaction starts, so a read-then-write
    # transaction waits out busy_timeout instead of failing immediately.
    default_transaction_mode: :immediate

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

  # The site's other hostnames redirect to the canonical one, so a browser
  # keeps one set of cookies (OaksWeb.Plugs.CanonicalHost). The api. hosts
  # stay as they are.
  config :oaks, OaksWeb.Plugs.CanonicalHost,
    host: host,
    aliases: [
      "www.oakcompendium.org",
      "oakcompendium.com",
      "www.oakcompendium.com",
      "oaks.fly.dev"
    ]

  config :oaks, OaksWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    check_origin: [
      "https://#{host}",
      "https://oaks.fly.dev",
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
