---
status: done
tags: [p2, security]
effort: M
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
relates: [7e4f, 63b3]
---

# Markdown raw HTML + no CSP + master key in localStorage

- lib/oaks/markdown.ex:14 MDEx unsafe_: true; output rendered with raw() at article_live.ex:202, species_detail_live.ex:696, species_compare_live.ex:274, taxonomy_live.ex:296, form_components.ex:82.
- Only key holders can author, but imported Oaks of the World text was never HTML-sanitized (cli/cmd/import_oaksoftheworld.go cleanText).
- .sobelow-conf skips Config.CSP; no CSP header.
- One <img onerror> -> exfiltrate localStorage['oak:api_key'] (non-expiring full-write credential).
Fix options: MDEx sanitize (allow-list), strict CSP via put_secure_browser_headers. Decide whether inline HTML in markdown is actually used (memory says MDEx chosen because Earmark escaped inline HTML — so some inline HTML IS intended). Needs a decision.

Done 2026-11-02: MDEx default sanitize (ammonia) on all markdown output — keeps links/images/tables/bold used by the draft 'how-to-document-an-oak-for-identification', strips scripts/handlers/iframes/styles/javascript: URLs. CSP on :browser pipeline (script-src 'self'; style-src allows inline; img-src https:). Removed inline onmouseover handlers in merge picker. Needs a browser check after deploy for CSP console violations.
