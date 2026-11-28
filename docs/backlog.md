# Backlog

Known bugs and ideas that belong to no plan. When one is picked up it moves into a plan doc, or is fixed directly if it's Small (AGENTS.md, Size the work). Bugs and ideas that belong to a plan are in that plan's docs ([Facts expansion](facts-expansion/README.md), [search](search-plan.md)).

## Bugs

- **404 floods write a row per request.** The analytics plug (`lib/oaks_web/plugs/analytics.ex`) inserts a `page_views` row for every 404, unrouted paths included. Each row is bounded, but inserts aren't sampled or capped, so a scanner flood writes a row per request. The daily rollup keeps the top 50 404s in `daily_error_stats`, but raw rows stay 30 days after their day is rolled up. The production volume once filled (1GB, now 3GB). Sample or cap 404 inserts under a flood.
- **Rendered Markdown keeps `class`.** `Oaks.Markdown` removes `style` from MDEx's default sanitizer allowlist but keeps `class` on `span`, `div`, `pre` and `code`, so stored content can pull in any site or Tailwind class, colours included.
- **URLs inside JSON link fields aren't validated.** `Species.external_links` and `Taxon.links` hold URLs that `ChangesetHelpers.validate_url` doesn't check.
- **A login rate-limit test fails on repeated runs.** In `test/oaks_web/controllers/user_session_controller_test.exs`, "too many code attempts are refused" uses the fixed IP 192.0.2.77, whose in-memory `LoginLimiter` counts survive across passes of `mix test --repeat-until-failure` in one VM, so a later pass's password step is refused (302 instead of 200).
- **Sandbox noise in the test log.** Test runs log `Exqlite.Connection disconnected: client exited` in about 6 of 9 runs and `cannot find ownership process` in about 1 of 30, because LiveViews and Tasks outlive the sandbox owner (`test/support/data_case.ex`). Done when repeated `mix test` runs show neither message.
- **Tests copy the login helper.** Seven test files each define `defp authenticated_conn`, duplicating ConnCase's `register_and_log_in_user`.
- **The toast after an update never times out.** After any save, the flash (`CoreComponents.flash/1`, `.oc-flash`) stays up until Jeff closes it; it should dismiss itself after a few seconds (Jeff, 2026-11-28). It has only its close button today, so a timer needs a hook (the CSP allows no inline script). Decide whether error flashes should stay until closed.

## Ideas

- **Passkeys for editor login.** WebAuthn passkeys (for example the `wax_` library) alongside password and TOTP: phishing-resistant and quicker on a phone. Discussed and deferred when the login was built.
- **Oak disease tolerance by species.** From someone who consults on oaks: which species struggle with which diseases. Red oaks in their area struggle with bacterial leaf scorch, but willow oak is much more tolerant, like the white oaks; *Q. lyrata* is reportedly highly tolerant of oak wilt. There is a good deal of misinformation about oak diseases, which often leads people to avoid planting oaks.
- **The USDA Oak Field Guide as a data source.** Find it (likely plants.usda.gov or fs.usda.gov), assess its species coverage, morphology and range data, decide whether it complements or duplicates Oaks of the World, and judge whether it can be scraped. `scrapers/usda_symbols.py` (USDA PLANTS symbols) already exists but points at a database that was deleted.
- **Add photos from another observation while a batch is adding.** In the species page's Add photos dialog (`OaksWeb.SpeciesPhotos.AddPhotos`), once the picked photos are adding (its `:adding` state), offer a way to load another iNaturalist observation and add its photos too, without waiting for the first batch (Jeff, 2026-11-28). Imports are durable work in `Oaks.Images`, so the first batch keeps going when the dialog moves on.
- **Finish the Oak Notes iOS app.** Left: iCloud or Markdown export, polish and TestFlight, fewer taps to start dictation, removing list timestamps, organizing by taxonomy. See [ios-oak-notes-app.md](ios-oak-notes-app.md).
