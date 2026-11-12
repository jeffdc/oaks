---
kind: decision
text: Sanitize markdown with MDEx's default (ammonia) allow-list and add a CSP
plan: audit-2026-11
source: matter 5453; commit 6d60022
by: /Users/jeff/dev/oaks
created: "2026-11-12T01:38:56Z"
---

Threat: lib/oaks/markdown.ex rendered with MDEx unsafe_: true, output went through raw() in five places (article, species detail, species compare, taxonomy, form preview), imported Oaks of the World text was never HTML-sanitized, and there was no CSP. One <img onerror> could exfiltrate localStorage['oak:api_key'], a non-expiring full-write credential. Some inline HTML is intended (MDEx was chosen because Earmark escaped it), so markdown keeps links, images, tables and bold, as used by the draft article 'how-to-document-an-oak-for-identification'. It strips scripts, event handlers, iframes, styles and javascript: URLs. CSP on :browser: script-src 'self', inline styles allowed, img-src https:. Replaces entry 856b.
