# Gallformers parity

Bring over operational and code patterns gallformers (`~/dev/gallformers`) already uses. Most are done or moved elsewhere (the API cache plug went to [Taxon pages](facts-expansion/taxon-pages.md)); one port is left. It is Small: it can be done directly in a branch.

## Decisions

- Telemetry: no metrics reporter for now (Jeff, 2026-11-21).
- The code-review command port is dropped (Jeff, 2026-11-26).

## 1. Structured JSON logging in prod

Fly.io's log aggregation is wasted on raw text. Switch prod logging to structured JSON; dev stays human-readable.

- Add the `:logger_json` dep to `mix.exs`.
- Configure it in `config/runtime.exs`, in the prod branch only. In gallformers (`config/runtime.exs`, the `if config_env() == :prod` block) it is `config :logger, :default_handler, formatter: LoggerJSON.Formatters.Basic.new(metadata: :all)`. It must live in `runtime.exs`, not `prod.exs`, because LoggerJSON has to be compiled before its formatter function can be called.
- Include `request_id` and the other standard metadata.

Done when prod logs on Fly are JSON lines carrying the request ID.

**Status:** not started (checked 2026-11-26: no `logger_json` in `mix.exs`).
