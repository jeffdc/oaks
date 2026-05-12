---
status: done
tags: [design, analytics]
created: 2026-05-12
updated: 2026-05-12
epic: gallformers-port
---

# Minimal self-hosted analytics

## Scope decision

Option B from the gallformers-analytics fork: self-hosted, minimal subset. Skipped option A (full gallformers port — Oban + 5 summary tables) and option C (Plausible/Fathom). YAGNI on rollups — at oaks scale (~300 req/day projected), querying raw page_views forever is fine. Add summaries only if/when query latency hurts.

## What gets counted

One row per non-bot, non-asset, non-admin GET request.

Captured and used per row:
- path
- status (HTTP response code)
- referrer_host (parsed from Referer header; null = direct or internal)
- visitor_hash = SHA256(today_date || ip || ua), daily rotation → no PII, no cross-day tracking
- inserted_at

Schema-aligned with gallformers but not captured/reported yet (columns present for forward compatibility):
- browser (text nullable) — left nil; no extraction in plug, no panel
- device_type (text nullable) — left nil; no extraction in plug, no panel

Rationale: keeps the schema 1:1 with gallformers' `page_views` so future expansion (device/browser panels) only requires turning on capture + adding panels; historical rows won't be missing the columns.

## Schema (single table)

page_views:
  id              integer primary key
  path            text not null
  status          integer not null      -- oaks addition (404s panel)
  referrer_host   text                  -- captured + reported
  browser         text                  -- column present, captured = nil
  device_type     text                  -- column present, captured = nil
  visitor_hash    text not null
  inserted_at     datetime not null

Indexes: (inserted_at), (path), (status), (visitor_hash, inserted_at)

Growth: ~150 bytes/row × ~300 req/day ≈ 16 MB/year.

## Components

**OaksWeb.Plugs.Analytics** (added to :browser pipeline)
- Runs in register_before_send so it fires after response is built
- Skip if: method ≠ GET; path under /api, /health, /assets, /favicon.ico; UA matches bot pattern (bot|crawler|spider|scrape|preview)
- Task.start(fn -> Oaks.Analytics.track(attrs) end) → never blocks request
- IP source priority: fly-client-ip > x-forwarded-for > conn.remote_ip

**OaksWeb.Analytics.TrackPageView** (on_mount hook)
- Captures LiveView SPA navigations (mount + handle_params)
- Reuses visitor_hash from session for consistency with the plug

**Oaks.Analytics** context
- track(attrs) — insert; Logger.warning on failure, never raises
- stats(from, to) — totals
- daily_stats(from, to) — per-day series
- top_pages(from, to, limit) — by views with unique-visitor count
- top_404s(from, to, limit) — status = 404

All queries hit raw page_views. SQLite-compatible: date(inserted_at), no ::date casts, no ON CONFLICT.

**OaksWeb.AnalyticsLive** at GET /analytics
- Public route (matches gallformers; aggregate-only, no PII; site is already public)
- Date range buttons: today / 7d / 30d / 90d / all
- Header card: total views, unique visitors
- Daily chart: dependency-free inline SVG sparkline (no D3)
- Top pages table
- Top 404s table

## Deliberately skipped

- Rollup/summary tables — defer until raw queries get slow
- Oban dependency — no scheduled jobs needed
- Retention/pruning — DB growth is trivial
- Device/browser breakdown — easy to add later from same raw data
- Referrer breakdown panel — column is captured, panel deferred
- Search-term tracking — different mechanism, defer
- Hourly granularity — daily is enough

## Ops characteristics

- Insert failures: Logger.warning, swallowed. Request always completes.
- No background jobs to monitor.
- No external services or new deps.
- SQLite single-writer: fine at oaks scale; busy_timeout=10s already configured.

## Testing

- Plug tests: skip rules (admin/assets/bots/POST), success path inserts a row
- Context tests: top_pages/top_404s/daily_stats/stats correctness with fixtures
- LiveView test: dashboard renders, range buttons swap data
- Uses page_view_fixture() built on the fixtures module from matter 651c

## Inspired by

/Users/jeff/dev/gallformers/lib/gallformers/analytics.ex
/Users/jeff/dev/gallformers/lib/gallformers/analytics/page_view.ex
/Users/jeff/dev/gallformers/lib/gallformers_web/plugs/analytics.ex
/Users/jeff/dev/gallformers/lib/gallformers_web/analytics/track_page_view.ex
/Users/jeff/dev/gallformers/lib/gallformers_web/live/analytics_live.ex

What we are NOT cribbing: rollup.ex, rollup_worker.ex, the 5 summary tables. Add later if needed.


---

## Implementation Plan

**Goal:** Self-hosted page-view analytics with a public dashboard at `/analytics` — tracking plug + LiveView SPA hook write to a single `page_views` table; dashboard shows totals, daily series, top pages, top 404s.

**Architecture:** One Ecto schema, one migration, one context module. Tracking is split: a Plug in the `:browser` pipeline handles dead-render requests; an `on_mount` hook handles LiveView WebSocket navigations. Both insert asynchronously through a `Task.Supervisor` so tests can synchronize. Queries hit the raw table — no rollups, no Oban.

**Stack:** Phoenix 1.8 LiveView, Ecto with `ecto_sqlite3`, Tailwind v4. No new deps.

---

### Task 1: Schema + migration

**Files:**
- Create: `priv/repo/migrations/<timestamp>_create_page_views.exs`
- Update: `priv/repo/structure.sql` (regenerate via `mix ecto.dump` after migrating)
- Create: `lib/oaks/analytics/page_view.ex`
- Test: `test/oaks/analytics/page_view_test.exs`

**Behavior:**
- `page_views` table with columns: `id` (auto), `path` (text not null), `status` (integer not null), `referrer_host` (text nullable), `browser` (text nullable), `device_type` (text nullable), `visitor_hash` (text not null), `inserted_at` (utc_datetime_usec not null). No `updated_at`. The `browser` and `device_type` columns are present for schema alignment with gallformers but are not populated (plug leaves them nil) and not queried; they cost ~0 storage when nil.
- Indexes: `(inserted_at)`, `(path)`, `(status)`, `(visitor_hash, inserted_at)`.
- `Oaks.Analytics.PageView` Ecto schema with `changeset/2` validating required fields (`path`, `status`, `visitor_hash`) and length limits (`path` ≤ 2000; `referrer_host`, `browser`, `device_type` each ≤ 255; `visitor_hash` exactly 64). `browser` and `device_type` are castable but optional.

**Testing:**
- changeset is valid with full attrs
- changeset is invalid when any of path / status / visitor_hash missing
- changeset accepts nil referrer_host, nil browser, nil device_type
- changeset rejects oversize path and wrong-length visitor_hash

---

### Task 2: Analytics context — visitor hash, track, basic stats

**Files:**
- Create: `lib/oaks/analytics.ex`
- Create: `test/support/fixtures/analytics_fixtures.ex` (`page_view_fixture/1`)
- Test: `test/oaks/analytics_test.exs`

**Behavior:**
- `visitor_hash(ip, user_agent)` → 64-char lowercase hex of `SHA256(today_iso_date <> ip <> user_agent)`. Stable within a UTC day.
- `track(attrs)` inserts a `PageView`. Returns `:ok | :error`. On failure logs `Logger.warning/1`; never raises.
- `stats(from_date, to_date)` → `%{page_views: int, unique_visitors: int}` for the inclusive range.
- `page_view_fixture(attrs \\ %{})` in fixtures module — inserts with defaults, used by tests in tasks 2/3/5/7.

**Testing:**
- `visitor_hash/2` is stable for identical inputs on the same day
- `visitor_hash/2` differs across different IPs / UAs
- `visitor_hash/2` returns 64-char hex
- `track/1` inserts when valid
- `track/1` returns `:error` (does not raise) when invalid; emits a warning log
- `stats/2` sums views correctly across date boundaries
- `stats/2` counts DISTINCT visitor_hash within range

**Notes:**
Date filtering — pick one approach and use consistently across the context: either inclusive `from_date` and exclusive `to_date+1day` over `inserted_at`, or `fragment("date(?)", pv.inserted_at)` between dates. SQLite supports both; the fragment form keeps queries readable.

---

### Task 3: Analytics context — daily series, top pages, top 404s

**Files:**
- Modify: `lib/oaks/analytics.ex`
- Modify: `test/oaks/analytics_test.exs`

**Behavior:**
- `daily_stats(from, to)` → `[%{date: Date.t(), page_views: int, unique_visitors: int}]`, one entry per day in range. Days with zero traffic are present with zero counts (gap-fill in Elixir; don't try to do it in SQL).
- `top_pages(from, to, limit \\ 20)` → `[%{path: string, page_views: int, unique_visitors: int}]`, ordered by views desc.
- `top_404s(from, to, limit \\ 20)` → `[%{path: string, count: int}]`, status = 404 only, ordered desc.

**Testing:**
- `daily_stats` fills missing days with zeros
- `daily_stats` unique counts are per-day, not deduplicated across the whole range
- `top_pages` orders correctly and respects limit
- `top_404s` excludes non-404 rows
- Case-sensitive path matching (document this in a doctest or test comment)

---

### Task 4: Tracking plug (`OaksWeb.Plugs.Analytics`)

**Files:**
- Create: `lib/oaks_web/plugs/analytics.ex`
- Test: `test/oaks_web/plugs/analytics_test.exs`

**Behavior:**
- `init/1` returns opts unchanged.
- `call/2`:
  1. Compute `visitor_hash` (so LV mount on the same request can read it from session). Put in session under `:visitor_hash`.
  2. `register_before_send/2` callback that, if `should_track?/1`, fires `Task.Supervisor.start_child(Oaks.TaskSupervisor, fn -> Oaks.Analytics.track(attrs) end)`.
- `should_track?/1` skip rules: method ≠ `GET`; path starts with `/api` or `/assets`, equals `/favicon.ico` or `/health`; UA matches `~r/bot|crawler|spider|scrape|preview/i`.
- IP extraction priority: `fly-client-ip` → first comma-segment of `x-forwarded-for` → `conn.remote_ip |> :inet.ntoa |> to_string`.
- Referer host: `URI.parse(referer).host`. Drop (set nil) if equal to `conn.host` or unparseable.
- Refactor the attrs builder into a pure private function `build_attrs/1` so it's directly testable.

**Testing:**
- Returns conn unchanged (status, body, halted)
- Skips non-GET methods
- Skips paths `/api/...`, `/assets/...`, `/favicon.ico`, `/health`
- Skips Googlebot UA
- Stores `visitor_hash` in session
- `build_attrs/1` (pure) returns expected map for representative conns
- Same-host Referer → `referrer_host` nil
- `fly-client-ip` header wins over `x-forwarded-for`

**Notes:**
Start `Oaks.TaskSupervisor` in `Oaks.Application` if it doesn't already exist (`{Task.Supervisor, name: Oaks.TaskSupervisor}`). End-to-end "does it write a row" verification belongs in Task 5; this task tests the plug in isolation.

---

### Task 5: Wire plug into router + integration test

**Files:**
- Modify: `lib/oaks_web/router.ex` (add `plug OaksWeb.Plugs.Analytics` to `:browser` pipeline only — NOT `:api` / `:api_force_auth`)
- Create: `test/oaks_web/analytics_integration_test.exs`

**Behavior:**
- Plug runs after `fetch_session` and `fetch_live_flash` in `:browser`.
- A GET to a tracked path inserts one row in `page_views`.

**Testing:**
- `GET /` inserts one row with `path: "/"`
- `GET /api/species` inserts nothing
- `GET /` with `User-Agent: Googlebot/2.1` inserts nothing
- Tests use `Task.Supervisor.children(Oaks.TaskSupervisor) |> Enum.each(&Task.await/1)` (or equivalent) to wait for async inserts before asserting.

---

### Task 6: LiveView SPA on_mount hook

**Files:**
- Create: `lib/oaks_web/analytics/track_page_view.ex`
- Modify: `lib/oaks_web/router.ex` (attach hook to the default `live_session`)
- Test: `test/oaks_web/analytics/track_page_view_test.exs`

**Behavior:**
- `on_mount(:default, _params, session, socket)`:
  - If `not connected?(socket)`, return `{:cont, socket}` (skip dead render).
  - Read `visitor_hash` from session; fall back to computing one from `get_connect_info(socket, :peer_data)` IP and `get_connect_info(socket, :user_agent)` if missing.
  - Track initial mount with current URI.
  - `attach_hook/4` for `:handle_params` lifecycle, tracking each URL change.
- All inserts go through `Oaks.TaskSupervisor`.

**Testing:**
- Mount with connected socket triggers a track
- `live_patch` to a different URL triggers another track
- Dead render (disconnected) triggers nothing
- Session `visitor_hash` is used when present
- Falls back to computing when session is empty

**Notes:**
Apply the hook to the existing default `live_session` only — opt-out from any admin/edit live_sessions if their privacy expectation differs.

---

### Task 7: Dashboard LiveView (`OaksWeb.AnalyticsLive`)

**Files:**
- Create: `lib/oaks_web/live/analytics_live.ex`
- Create: `lib/oaks_web/live/analytics_live.html.heex`
- Modify: `lib/oaks_web/router.ex` (`live "/analytics", AnalyticsLive` in a public scope)
- Test: `test/oaks_web/live/analytics_live_test.exs`

**Behavior:**
- Public route, no auth.
- Range options: `:today`, `:last_7`, `:last_30`, `:last_90`, `:all`. Default `:last_7`.
- Mount computes and assigns: `range`, `from`, `to`, `stats`, `daily`, `top_pages`, `top_404s`.
- `handle_event("set_range", %{"range" => r}, socket)` swaps range, recomputes data, `push_patch` to URL with `?range=...`.
- Template:
  - Range button row
  - Header card: total views, unique visitors
  - Inline SVG sparkline of daily views (~30 lines of heex; normalize counts to 0–1, render as `<polyline>`)
  - Top pages table (path, views, unique)
  - Top 404s table (path, count) — hide section when empty

**Testing:**
- Mount renders default 7d range
- Clicking 30d updates the rendered totals (use `render_click/3`)
- Top pages table renders fixture entries
- Top 404s table is hidden when no 404s in range
- `:all` range queries from earliest row

**Notes:**
Sparkline is dependency-free. No D3, no chart library. If it ever needs to be richer, that's a follow-up matter.

---

## Execution order

Tasks 1 → 2 → 3 (context layer). Then 4 → 5 (plug + wiring). Then 6 (LV hook). Then 7 (dashboard). Each task is independently green-able and committable. Task 5 is the first end-to-end "rows appear in DB from real traffic" milestone; task 7 is the first "you can actually look at the data" milestone.
