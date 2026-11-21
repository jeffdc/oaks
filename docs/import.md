# Bulk imports: a producer's guide

Every bulk change to the Oak Compendium's data goes through one endpoint, `POST /api/private/v1/import`, never through SQL. This note is for the agent or script that builds the body. The code is `Oaks.Import` (domain) and `OaksWeb.PrivateAPI.ImportController` (endpoint).

## The rule: dry run, Jeff reads it, then apply

1. Dry-run the body: `POST /api/private/v1/import?dry_run=true`. It validates every record, reports what would be created and changed, writes nothing, and returns a `dry_run_token`.
2. Show Jeff the report (the summary and the records, with their changes) and wait for his OK. Don't apply without it.
3. Apply the same bytes: `POST /api/private/v1/import` with the header `dry-run-token: <token>`.

The server enforces this: an apply without a token from a dry run of the exact same bytes, made with the same agent token in the last 24 hours, is refused (428). If the database has changed since the dry run so that the apply would do something other than what the report showed, the apply is refused too (409); dry-run again and show Jeff the new report.

## Access

You need an agent token with the `packages:submit` scope, which Jeff issues at `/users/settings/api-tokens`. Send it as `Authorization: Bearer oak_...`. The private API's usual limits apply: 120 requests a minute per token, and bodies up to 8 MB.

## Send the file byte for byte

The dry-run token is tied to the SHA-256 of the raw request body, not to its meaning: re-encoding the JSON, reordering keys or changing whitespace makes a different body. Write the body to a file once and send that file both times. With curl, use `--data-binary @file`, not `-d @file` (which strips newlines):

```bash
curl -sS -X POST 'https://oakcompendium.org/api/private/v1/import?dry_run=true' \
  -H "Authorization: Bearer $OAK_TOKEN" -H 'content-type: application/json' \
  --data-binary @import.json

curl -sS -X POST 'https://oakcompendium.org/api/private/v1/import' \
  -H "Authorization: Bearer $OAK_TOKEN" -H 'content-type: application/json' \
  -H "dry-run-token: $DRY_RUN_TOKEN" \
  --data-binary @import.json
```

The body must be sent as `content-type: application/json`. `dry_run` goes in the query string and the token in a header, never in the body.

## The body

A JSON object with one key per table, each a list of records, and an optional `import_id`:

```json
{
  "import_id": "sibley-2026-11-batch-1",
  "sources": [
    {"$ref": "sibley", "source_type": "book", "name": "The Sibley Guide to Trees", "author": "David Allen Sibley", "year": 2009}
  ],
  "species": [
    {"$ref": "alba", "scientific_name": "alba", "author": "L. 1753", "is_hybrid": false},
    {"$find": {"scientific_name": "rubra"}, "author": "L. 1753"}
  ],
  "species_sources": [
    {"species_id": {"$ref": "alba"}, "source_id": {"$ref": "sibley"}, "bark": "Pale gray, scaly."},
    {"$find": {"species_id": {"$find": {"scientific_name": "rubra"}}, "source_id": 2}, "leaves": "Lobed, bristle-tipped."}
  ]
}
```

Tables are processed in this order, whatever order the keys are in, and the records of each table in array order: `sources`, `species`, `taxa`, `species_sources`. Field names and types are exactly those of the Ecto schemas named below; unknown tables, unknown fields and unknown `$` keys are errors.

### Tables and fields

- `sources` (`Oaks.Sources.Source`): `source_type` and `name` (required), `description`, `author`, `year` (integer), `url`, `isbn`, `doi`, `notes`, `license`, `license_url`.
- `species` (`Oaks.Species.Species`): `scientific_name` (required, unique), `author`, `is_hybrid` (boolean, default false; must be true when the name contains ×), `conservation_status` (one of EX EW CR EN VU NT LC DD NE), `subgenus`, `section`, `subsection`, `complex`, `parent1`, `parent2`, `hybrids`, `closely_related_to`, `subspecies_varieties`, `synonyms`, `external_links`.
- `taxa` (`Oaks.Taxonomy.Taxon`, the current taxonomy table): `name` and `level` (required; level is subgenus, section, subsection or complex; the pair is unique), `parent` (the parent taxon's name), `author`, `content`, `content_updated_at`, `links`. Changing `content` on an update stamps `content_updated_at` with today's date, as the app does.
- `species_sources` (`Oaks.Sources.SpeciesSource`): `species_id` and `source_id` (required; one row per pair), `local_names`, `range`, `growth_habit`, `leaves`, `flowers`, `fruits`, `bark`, `twigs`, `buds`, `hardiness_habitat`, `miscellaneous`, `url`, `is_preferred` (boolean).

List fields (`hybrids`, `closely_related_to`, `subspecies_varieties`, `synonyms`, `local_names`) are strings, as in the app's forms: a comma-separated list (`"alba, rubra"`) or a JSON array written as a string (`"[\"alba\", \"rubra\"]"`; `synonyms` entries may also be `{"name": ...}` objects). They are stored as a normalized JSON array.

### Create or update

- A record with neither `id` nor `$find` creates a row.
- `"id": 12` updates the existing row with that id.
- `"$find": {"field": value, ...}` updates the one existing row whose fields equal those values. Matching no row or more than one is an error.

An update changes only the fields you give. If they already have those values, the record is reported as `unchanged` and nothing is written. There is no upsert and no delete.

Renames are refused: an update can't change a species' `scientific_name` or a taxon's `name` or `level`, because the app updates every reference to the old name when it renames. Rename those in the app.

### Refs between records

- `"$ref": "name"` names a record so later records can point at it. Names are unique across the body. Updates (`id` or `$find`) can have a `$ref` too.
- A foreign key (`species_sources.species_id`, `species_sources.source_id`) takes an integer id, `{"$ref": "name"}` or `{"$find": {...}}` on the key's table. A `$find` can itself use refs or `$find`s for its own foreign keys, as in the example.
- A `$ref` must name a record of the key's table that comes earlier in processing order. Refs never point forward.
- If a record has errors, records that refer to it get the error "refers to <name>, which has errors".

## Responses

A dry run (200):

```json
{
  "status": "dry_run",
  "body_sha256": "9f2c...",
  "dry_run_token": "SFMyNTY...",
  "token_expires_at": "2026-11-22T18:00:00Z",
  "summary": {"species": {"create": 1, "update": 1, "unchanged": 0}},
  "records": [
    {"table": "species", "index": 0, "ref": "alba", "action": "create", "changes": {"scientific_name": "alba", "author": "L. 1753"}},
    {"table": "species", "index": 1, "ref": null, "action": "update", "id": 57, "changes": {"author": {"from": "L.", "to": "L. 1753"}}}
  ]
}
```

Creates list the fields they set; a foreign key to a record in the body shows as `{"$ref": "name"}`. Updates list each changed field's `from` and `to`. An apply (200) returns the same report with `"status": "applied"` and the `id` of every created row.

Errors (422) list every problem found, one entry per message, and nothing is written:

```json
{"errors": [
  {"table": "species", "index": 1, "ref": null, "field": "conservation_status", "message": "is invalid"},
  {"table": null, "index": null, "ref": null, "field": null, "message": "\"articles\" is not a table the import accepts (sources, species, taxa, species_sources)"}
]}
```

`table`, `index` and `field` are null for errors about the body as a whole. Problems with the body's shape (unknown tables or fields, bad refs) are reported before any record is checked against the database.

### Status codes

- 200: a dry run, an apply, or an import that was already applied (`"status": "already_applied"`, with `applied_at`).
- 400: the body isn't valid JSON, or `dry_run` has a value other than `true`.
- 401: no valid agent token. 403: the token lacks `packages:submit`. 429: too many requests.
- 413: the body is over 8 MB.
- 415: the body isn't `application/json`.
- 422: records with errors (see above).
- 428: the apply's dry-run token is missing, invalid, expired, for a different body, or from another agent token. The message says which.
- 409: the database changed since the dry run (dry-run again), or the `import_id` was already applied with a different body.

## Re-sending and import_id

Every applied body is recorded. Sending the same bytes again, as a dry run or an apply, does nothing and returns `already_applied`. Give an `import_id` (a string of up to 200 bytes) to name an import: a body with an `import_id` that was already applied with different bytes is refused with 409, so a corrected batch needs a new `import_id`.
