Oak Compendium's rules are in `docs/architecture/rules.md`; CODING_STANDARDS.md, DESIGN.md and AGENTS.md are their sources. These rules need judgement, so no check holds them yet (the first triage, in `docs/facts-expansion/architecture-groundwork.md`, section 5). For each, report violations beyond its baseline, and say whether a check could now hold it.

1. **Contexts and their tables (S1, S2).** Has any module started reading or writing another context's tables, or the web layer reaching `Oaks.Repo` or `Ecto.Query`, beyond the exceptions rules.md lists? Is a recorded exception still needed?
2. **Raw SQL (D2).** Is there raw SQL beyond the four recorded exceptions, and does each still need it?
3. **JSON in TEXT columns (D4).** Has a migration or schema added a JSON column, or a JSON value that the database queries, filters or joins on, or that points at another row?
4. **Writes behind the scope check (W1).** Does every `handle_event` that writes re-check `@current_scope`, in every editor LiveView and LiveComponent, not only those with forged-event tests?
5. **Personal data in logs (W6).** Does any `Logger` call, error message or telemetry metadata carry an email, token, IP address or other personal data?
6. **The component library (U1, U2).** Does any page build its own version of something the library covers in a way `OaksWeb.Conformance` doesn't catch (a button, table, dialog or notice of its own), or restyle an `oc-` class from page CSS?
7. **Shared code (U8).** Does oaks reach the photo viewer (`Heartwood.UI.PhotoViewer`) only through `<.species_photos>`, and theme it only through `.oc-photos`, never its `pv-` classes? Is there other code gallformers has too that should move to heartwood?
8. **Tests and the seeds (T1).** Does any test read rows from `priv/repo/test_seeds.sql` instead of building its own with the fixtures?
