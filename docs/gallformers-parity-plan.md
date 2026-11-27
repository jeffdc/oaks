# Gallformers parity

Bring over operational and code patterns gallformers (`~/dev/gallformers`) already uses. Most are done or moved elsewhere (the API cache plug went to [Taxon pages](facts-expansion/taxon-pages.md)); two ports are left. They are independent and Small: each can be done directly in a branch.

## Decisions

- Telemetry: no metrics reporter for now (Jeff, 2026-11-21).

## 1. Structured JSON logging in prod

Fly.io's log aggregation is wasted on raw text. Switch prod logging to structured JSON; dev stays human-readable.

- Add the `:logger_json` dep to `mix.exs`.
- Configure it in `config/runtime.exs`, in the prod branch only. In gallformers (`config/runtime.exs`, the `if config_env() == :prod` block) it is `config :logger, :default_handler, formatter: LoggerJSON.Formatters.Basic.new(metadata: :all)`. It must live in `runtime.exs`, not `prod.exs`, because LoggerJSON has to be compiled before its formatter function can be called.
- Include `request_id` and the other standard metadata.

Done when prod logs on Fly are JSON lines carrying the request ID.

## 2. Code-review command

Adopt gallformers' code-review rubric as an oaks command: copy `~/dev/gallformers/prompts/code-review.md` to `.claude/commands/review.md` (beside `release.md`), replace gallformers and Postgres references with oaks, SQLite and LiveView, and adjust for oaks' context (the sources model: iNaturalist 1, Oaks of the World 2, Oak Compendium 3; taxonomy specifics). Keep the rubric's structure: severity levels, plus correctness, idiom, performance, security, tests and clarity.

Done when the command exists and has reviewed one real branch.

## To work out

- Claude Code now has a built-in `/code-review`. Whether the oaks rubric is still wanted (perhaps as project guidance the built-in review reads), or this port is dropped.

**Status:** neither started (checked 2026-11-26: no `logger_json` in `mix.exs`, no `.claude/commands/review.md`).
