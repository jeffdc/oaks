# Species photos

Add photos to species, imported only from iNaturalist, stored in S3, served through CloudFront on `images.oakcompendium.org`, and shown in a photo viewer built as a component shared with gallformers. The model is gallformers on the `taxogall` branch; "port" below means copy from there and adapt.

The plan also rebuilds the species page as an intermediate step towards the redesign's taxon page (`design/prototype/shumardii.html`, brief in `.impeccable/surfaces/design-prototype-shumardii-html.md`, rules in DESIGN.md), and lets an editor add an iNat observation's photos from that page. The design to build is Phase 4's: `design/prototype/species-today.html` and the Phase 4 decisions. Where they differ from DESIGN.md or the redesign prototype, the Phase 4 decisions win for this plan; the redesign is revisited when the facts model exists.

## Decisions

- Photos come only from iNat observations. Browser and phone uploads are out of scope.
- The S3 bucket is private. CloudFront reads it through Origin Access Control (OAC) and serves it on the custom domain `images.oakcompendium.org`, with an ACM certificate in us-east-1. Jeff updates DNS.
- Variants: small 300, medium 800, large 1200 and xlarge 2000 px, plus the original.
- Dev uses a local storage adapter with no AWS credentials.
- AWS is managed with OpenTofu, its state in S3, as in gallformers. Fly stays managed with `fly.toml` and `fly secrets`.
- CSP needs no change: `img-src` already allows `https:` (`lib/oaks_web/plugs/security_headers.ex`).
- The species page follows the Phase 4 design: an intermediate page built from the data that exists today, which keeps the source tabs and shows all text. It deviates from the redesign's taxon page where Jeff chose to (Phase 4 decisions).
- Editors add photos from the species page itself, not the species edit page.
- Every photo imported here is an exemplar photo. The other observation roles in the compendium plan (evidence, material, trait illustration) are out of scope.
- Imports have pending, ready and failed states. Only ready photos are public, after the original and all four variants are stored. Successful photos survive a partial batch failure; interrupted work is recoverable and retries do not duplicate photos.
- Merging species appends the source's photos after the target's. For duplicate iNat photo IDs, the target's photo and caption win; the merge preview shows this. Deleting a photo or species hides its photos at commit and schedules storage cleanup after commit.
- Removal includes deleting the original and every variant and invalidating their CloudFront paths, with retries. Deleted S3 versions are retained for 30 days before lifecycle cleanup; current live images do not expire.
- The rebuild preserves all existing content, relationships, links and editor actions. Phase 4 decides their placement. `closely_related_to` is no longer shown (Jeff, 2026-11-25: the taxonomy already holds it; the field is to be dropped later); all agreement and review-status marks wait for the facts model.
- Where one value is needed, select a nonempty value per field in source order: the preferred source, then Oak Compendium, then Oaks of the World, then the rest alphabetically (Jeff, 2026-11-25). Always identify the supplying source; keep other sources' values accessible. Phase 4 defines the exact display contract below.

## Phase 0: Infra baseline

`infra/` describes resources made by hand. It has never been applied and has no state.

1. Add `opentofu` to `flake.nix`.
2. Create the state bucket `oaks-terraform-state` by hand (versioned, encrypted). Add an `s3` backend with `use_lockfile = true`. Move to AWS provider 6.x and tofu 1.10 or later.
3. Remove the `fly` provider, `fly_app`, `fly_volume` and the `secret_key_base` variable.
4. Run `tofu import` on the Litestream bucket and its versioning, lifecycle and public-access-block settings, and on the IAM user, policy, attachment and access key.
5. Add `infra/README.md` listing the resources and how to run tofu.

Done when `tofu plan` shows no changes. Jeff runs steps 2 and 4 against AWS, or OKs Claude running them.

**Status: done.** OpenTofu comes from the flake; state is in `oaks-terraform-state` (made by hand: versioned, SSE-S3, public access blocked) with `use_lockfile`, on AWS provider 6.x. The Fly provider, app, volume and `secret_key_base` are gone. The Litestream bucket, its versioning, lifecycle and public access block, and its IAM user, policy, attachment and key were imported (3f7b9b6). `infra/README.md` lists every resource. `tofu plan` showed no changes on 2026-11-25.

## Phase 1: Images infra

New files, split as gallformers does:

- `s3.tf`: the `oaks-images` bucket, versioned, all public access blocked, with a bucket policy that lets only the distribution read (OAC). Lifecycle expires noncurrent versions after 30 days and removes expired delete markers; it does not expire current live objects. The 30 days start when a version becomes noncurrent, not when the photo was imported; AWS performs expiration asynchronously ([S3 lifecycle](https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-expire-general-considerations.html)).
- `cloudfront.tf`: the OAC, and a distribution with the alias `images.oakcompendium.org`, HTTPS only and a long cache TTL. Image paths are unique per import attempt. Removal invalidates every path after storage deletion; unique paths do not evict cached removals ([CloudFront invalidation](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Invalidation.html)).
- `acm.tf`: a certificate for `images.oakcompendium.org` in us-east-1, with DNS validation. Outputs give the validation CNAME and the distribution's domain for Jeff to add to DNS.
- `iam.tf`: the `oaks-images-upload` user, allowed `s3:PutObject`, `s3:DeleteObject` and `s3:ListBucket` on the images bucket, plus `cloudfront:CreateInvalidation` and `cloudfront:GetInvalidation` on this distribution. Its access key goes into Fly secrets; the distribution ID goes into runtime configuration. Permanent version expiration is handled by the bucket lifecycle.

Done when an object put with the upload key is served from `https://images.oakcompendium.org/...`, deletion plus completed invalidation stops a fresh request serving it, and the plan includes the 30-day noncurrent-version lifecycle without expiring live images.

**Status: done.** Applied 2026-11-24 (028102d); the distribution is `E1GM6FGGDJPT7E`. Jeff added the certificate's validation CNAME and the `images` CNAME at Porkbun. The upload user's access key is made outside tofu, so its secret never enters state. The AWS smoke checks passed; their results are under Production smoke checks, below the acceptance checks.

## Phase 2: Storage layer

- Deps: `ex_aws`, `ex_aws_s3`, `sweet_xml`, `hackney` and `image` (libvips, which the flake and the Dockerfile need), plus a CloudFront API client for invalidation. Make `req` a runtime dep.
- Config: `config :oaks, :images` with the adapter, bucket, `cdn_url` and distribution ID. `runtime.exs` reads the keys from env. Test uses a mock adapter for failure cases and Local for real image processing.
- `Oaks.Storage.Images` is the API: `put/3`, `delete/1`, `list/1`, `public_url/1`, `variant_url/2`. Paths are `species/{id}/{id}_{ts}_{uniq}_original.{ext}`. Port from `lib/gallformers/storage/images.ex`.
- Adapters: `S3`, ported from `lib/gallformers/storage/s3.ex`; and `Local`, which writes to `tmp/images` and is served by `Plug.Static` at `/dev-images` in dev only.
- Add an invalidation boundary with submit and completion checks; Local completes it as a no-op. Persist the invalidation ID so a restart can resume checking it.
- Variants: adapt `generate_size_variants/2` to process original bytes with `Image` and return the generated variants only after all sizes succeed. The Phase 3 worker stores the original and variants. Do not port gallformers' CDN re-download, fixed sleep or fire-and-forget resize tasks: none establishes readiness, and a dev URL is not a storage read API.

Done when dev and prod can both store an image, make its variants and serve it, real resizing is tested through Local, and storage/invalidation failures can be injected through the mock.

**Status: done.** Built in faf72f6. `Oaks.Storage.Images` sits in front of the `Oaks.Storage.Adapter` contract: `S3` in prod (ex_aws on Req, with CloudFront invalidation signed by Req's SigV4, so there is no separate CloudFront client), `Local` in dev and a Mox mock in tests. hackney isn't used: ex_aws 2.8 needs hackney 4, and Req is already the app's client. libvips comes from the flake and Alpine, with vix compiled against it. The bucket, `cdn_url` and distribution ID are in `config/config.exs`; only the upload key comes from the environment (`config/runtime.exs`). The S3 adapter was smoke-tested from dev against the real bucket and CDN on 2026-11-24.

## Phase 3: iNat client and data

- Port `Gallformers.INaturalist` with its `Observation` and `Photo` structs: `parse_observation_id/1` (a URL or an ID), `fetch_observation/1`, `download_photo/1`, `map_license/1`, `format_creator/2`. Tests stub iNat with `Req.Test`.
- Port `Gallformers.Licenses` and `Gallformers.Images.Attribution`.
- Migration for the `images` table: `species_id` (FK), `path`, `sort_order`, `caption`, `creator`, `license`, `licenselink`, `sourcelink`, `inat_observation_id`, `inat_photo_id`, `uploader`, `lastchangedby`, `status` (`pending`, `ready`, `failed`), last import error, timestamps. Require the iNat IDs and enforce uniqueness on (`species_id`, `inat_photo_id`) across all states. The FK must not silently cascade away photos without recording cleanup.
- Persist import attempts and cleanup operations in SQLite, including their object paths, attempt identity, retry information and invalidation ID. Cleanup records survive deletion of their image and species; a running Task is not the record of outstanding work.
- `Oaks.Images`: `list_for_species/1` returns ready photos in order; a separate editor query includes pending and failed imports. Adapt `import_inat_photo/4` to reserve the row and enqueue work; add retry and progress queries. Keep `update_caption/3`, `reorder/2` and `delete/1`, with the transaction and cleanup rules below. Port the useful pieces from `lib/gallformers/images.ex`.
- All Rights Reserved photos may be imported only with the editor's explicit confirmation that the creator has given permission; the import context rejects them without it, and the confirmation is recorded with the photo (Jeff, 2026-11-25; this reverses the earlier rejection, so Phase 3's import code needs that change, made with Phase 5). Every iNat photo carries a license; if one ever arrives with none or an unknown one, it is not mapped to All Rights Reserved but flagged as such ("No license given") and left to the editor, under the same permission confirmation. Attribution comes from server-fetched observation/photo data; species ownership and uploader come from the current species and authenticated editor on the server.

### Import and recovery contract

1. Reserve the pending image and an attempt with unique object paths in one database transaction, before storage writes. A repeated import of a ready or pending photo reports its existing state; a failed photo is retried through the same image row. Concurrent requests are covered by the unique constraint.
2. A supervised worker downloads the photo, generates the four variants and stores all five files. Mark the image ready only after every write succeeds and the attempt is still current. Do not hold a database transaction open during network or image work.
3. On failure, keep the photo hidden, record a useful error and persist cleanup of any attempted paths. A retry uses fresh paths, so cleanup of an older attempt cannot delete its replacement. If storage succeeds but the ready-state update fails, the persisted attempt still permits recovery and cleanup.
4. Resume interrupted pending work and unfinished cleanup on application startup. Claims prevent duplicate workers; an obsolete attempt cannot publish after retry, merge deduplication or deletion. Coordinate active workers and cleanup so late uploads cannot recreate removed files. Retry transient failures with backoff; exhausted imports become failed and can be retried by an editor. Cleanup retries continue with backoff, with failures recorded until resolved.
5. Each photo is independent: retain successful photos when other selections fail. Closing the dialog or disconnecting does not cancel durable work; reopening shows its saved state. The editor can retry failed photos without importing successful ones again.

### Merge and removal contract

- Extend `Oaks.Species.Merge.preview_merge/2` and `execute_merge/3`: show photos to transfer and duplicate iNat IDs, including captions that will be discarded. Keep each target photo, caption and position; append unique source photos in source order. Move pending/failed records too. Preserve stored paths when ownership moves; a species ID in a path is not the ownership authority.
- Commit image reassignment, duplicate removal and cleanup records in the species merge transaction. A rolled-back merge must leave all files intact. Workers resolve the current image ownership before publishing.
- Extend `Oaks.Species.delete_species/1` and its confirmation to include images. Individual photo deletion and species deletion remove the image rows and record all attempted original/variant paths for cleanup in the same transaction. Readers stop seeing removed photos at commit; storage work starts only after commit.
- Cleanup deletes all recorded objects, then submits and waits for CloudFront invalidation of their paths. It is safe to repeat after a crash or partial failure. Do not report storage cleanup complete merely because the image row was deleted or invalidation was accepted. Saved copies and browser caches cannot be recalled; the guarantee is removal from the site and, after cleanup completes, no fresh CDN delivery of the removed files.
- S3 retains the deleted versions for the agreed 30-day lifecycle period; Local removes its files without version retention. Retries and re-imports use new paths and cannot be affected by cleanup of an earlier import.

Done when an observation becomes ready images with full attribution, the import/recovery and merge/removal contracts pass the acceptance checks below, and no failed or interrupted operation leaves untracked storage work.

**Status: done.** Built in 5b8ca89; All Rights Reserved photos with recorded permission came with Phase 5 (59a7312). Durable work runs on Oban (Lite engine, in the app's SQLite database): `Oaks.Images.ImportWorker`, `CleanupWorker`, and `RecoveryWorker`, which re-enqueues unfinished work at boot and every 15 minutes. The images' species FK restricts deletes, so photos can't vanish without a cleanup; cleanup rows keep no FK and outlive their image and species. Every acceptance row is covered by a test or a recorded check (PR #15 lists them).

## Phase 4: Species page design for today's data

Work with Impeccable (`impeccable:impeccable`) to adapt the taxon page prototype to the data the site has now. This is Large work: the full process, with Impeccable's decision page and Jeff's choices, before any build. The result is an updated prototype in `design/prototype/` and the decisions recorded in this plan.

What today's data can and can't fill (a starting point for the design, not a layout):

| Prototype section | Today's data | This plan |
|---|---|---|
| Taxonomy band, title row, IUCN stamp | Already built, including scientific name and author | Kept |
| Siblings menu in the band | Taxonomy | Built |
| Common name in the title | Sources' local names | Built using the per-field selection rule below; retain all names with their sources |
| Photos and carousel | The images from Phases 3 and 5 | Built |
| Write-up (fragment and reader) | Oak Compendium's text, by field | Waits (Phase 4 decision: all text shown in the source tabs) |
| Hybrids, each with its other parent | `hybrids`, `parent1`, `parent2` | Built |
| Parents of a hybrid | `parent1`, `parent2` | Kept as the title row's subtitle, including when only one parent is known |
| Subspecies and varieties | `subspecies_varieties` | Kept |
| Closely related | `closely_related_to`, names only | Not shown (Phase 4 decision); the data stays until it is dropped |
| Field marks table | `growth_habit`, `leaves`, `flowers`, `fruits`, `bark`, `twigs`, `buds` per source | Waits (Phase 4 decision: the source tabs stay) |
| Hardiness and habitat; additional information | `hardiness_habitat`, `miscellaneous` per source | Kept in full in each source's tab |
| Range | Each source's range text | Partly: text per source in its tab; no map place, place list, native or introduced |
| Name and synonyms | `synonyms` | Partly: no accepted or misapplied status |
| Sources and cite-this-page line | The species' sources | Built |
| Original-source and external links | Each source row's `url`, species `external_links`, computed links | Kept |
| Species editor actions | Edit, delete, make synonym of another species, add source data | Kept; merge/delete include photos |
| Per-source editor actions | Edit source data, delete source data | Kept, in a quiet Edit menu beside the tabs |
| Link to the source comparison | `SpeciesCompareLive` | Built |
| What sets it apart (ranked traits) | None | Waits for the facts model |
| Look-alike claims | No explicit visual-similarity data | Waits; closely related names are not relabelled as look-alikes |
| Agree, differs and unreviewed marks | None | Waits for the facts model |
| Taxon comparison (`?vs=`) | None | Waits for the facts model |
| The page in the 1400px frame | | Built in two columns (Phase 4 decision) |

Data display contract:

- For each field independently, skip nil, empty and whitespace-only values. Use the source order: the row marked `is_preferred`, then Oak Compendium (source 3), then Oaks of the World (source 2), then the remaining sources by name. Where Oak Compendium isn't the preferred source, Oaks of the World should be. For common names, skip sources whose parsed list has no nonempty name, and use the first nonempty name in the chosen source's stored list for the title.
- Keep the supplying source attached to every displayed value. Other sources' nonempty values and all common names remain accessible in their tabs; a fallback value never appears as Oak Compendium's text. Preserve full stored text and Markdown.
- If no source supplies a field, omit that field or use the approved empty-state wording; never invent a value or a review status. Missing Oak Compendium text has no substitute attributed to Oak Compendium.
- Preserve source comparison, synonym redirects, real not-found responses and all existing editor actions. This is a presentation change, not removal of stored fields or changes to the public API.

Open questions for the design pass (all settled by the Phase 4 decisions below):

- What the reading column holds while there are no distinguishing traits.
- Whether Oak Compendium's text stands in for Jeff's write-up, and how the page says what it is.
- Where editors manage photos (captions, order, delete): a dialog on the species page or elsewhere.
- Where the preserved content and editor actions fit, and how closely related names, field marks, range and synonyms read with the data available.
- The add-observation dialog, starting from the Observation panel in `design/prototype/id-mode.html` (URL and Load, the photo strip, the observation's meta line).
- Empty and sparse states: no photos, one photo, many photos, pending/failed imports for editors, no Oak Compendium text, other-source-only data, no source data, a hybrid and a variety.

Done when Jeff has approved the adapted prototype, including sparse states and destinations for every preserved field/action, and its decisions are written here.

**Status: done.** Jeff approved `design/prototype/species-today.html` on 2026-11-25.

### Phase 4 decisions (Jeff, 2026-11-25)

The prototype is `design/prototype/species-today.html`: six real taxa from the database, with a state switcher for photo count, reader or editor view, and the photo dialogs. This page is an intermediate step between today's page and the redesign's taxon page, and will be revisited when the facts model exists, so it deviates from the prototype and DESIGN.md where Jeff chose to.

- **Attribution.** The site never labels its own data with Jeff's name. Oak Compendium's text is attributed to "Oak Compendium" or not labelled; the cite line names the site: "Oak Compendium. *Quercus shumardii* Buckley. https://oakcompendium.org/species/shumardii (accessed …)." Articles keep their author's byline.
- **Layout.** Two columns in the 1400px frame: photos left (300px, sticky; 240px under 1180px), the source text right. On phones one column: the text, then the photos (DESIGN.md's phone order), then everything below. This replaces the three columns in the scope table.
- **Source text in tabs, as today.** One tab per source, in the source order: the preferred source, then Oak Compendium, then Oaks of the World, then the rest alphabetically. The page opens on the first tab with any text, so every taxon shows its default source and sparse Oak Compendium data needs no special layout; an empty row stays a tab and reads "No text from {source} yet." "Preferred" is never shown: it only tells the system which source opens first. The source's name appears once, in its tab. The open tab carries one small icon link: to the original page when the row has a URL (Oaks of the World), otherwise to the source's page on the site (Sibley, Oak Compendium). For editors, a quiet Edit menu at the right of the tabs holds Edit {source} data and Delete {source} data. Compare sources sits at the right of the tabs when there are two or more sources. The common name's source mark in the title row opens that source's tab.
- **All text shown.** Nothing is hidden behind a click: every nonempty field of the open source, in full, in today's order and labels (Common names, Geographic range, Growth habit, Leaves, Flowers, Fruits, Bark, Twigs, Buds, Hardiness and habitat, Additional information). Inside a tab the text is set as that source's prose, attributed by the tab head, not in quotation marks. There is no write-up fragment or reader and no field marks table in this design.
- **Title row.** Name, author, the common name chosen by the display contract with its source mark, the kind word and the IUCN stamp. A hybrid's parents are the title row's subtitle: "Hybrid of *Q. rubra* and *Q. shumardii*", or "… and an unrecorded parent" when one is known. The siblings menu sits in the band.
- **Not covered.** A taxon with no Oak Compendium text gets the DESIGN.md not-covered notice under the title row. A taxon with no source rows shows "No source data for this oak yet." where the tabs would be.
- **Photos column.** Ready photos only, in the photo viewer: the medium image, its caption, then the credit, license and iNaturalist link; under it a rail of thumbnails that shows five at a time (six on phones) with step buttons to page through the rest, and a count. Left/Right keys move photo by photo. The viewer is a shared component, built to move to Gallformers (`design/prototype/photo-viewer.css` and `photo-viewer.js`: markup-driven, themed by custom properties, no page code). With no photos it reads "No photos yet." (hidden on phones). No range map place in this design.
- **Below the main content,** in order: Synonyms, Subspecies and varieties, Hybrids (each with its other parent), External links, Sources, the cite line. Each section appears only when it has data.
- **Editor actions.** The title row's Edit menu holds Edit species, Add source data, Add photos from iNaturalist…, Manage photos… (noting failed imports, e.g. "1 failed"), Make synonym of… and Delete species. Editing never changes the reader's layout.
- **Add photos dialog** (`<.modal>`): an "iNaturalist observation" field (URL or number) with Load; then the observation's meta line (observer, place, date, taxon) and its photos as a grid with checkboxes and licenses. All Rights Reserved photos can be picked but are stamped "All rights reserved"; picking one shows, between ink rules, that its creator keeps every right and it may be added only with the creator's permission, with a required box "The creator has given permission to use this photo." Add stays disabled until it is ticked. On the page such a photo's credit reads "All rights reserved, used with the creator's permission". Photos already imported show "Already added". The action is "Add N photos". After it, each photo shows Added, Adding… or Failed with the error and Retry, with the note that closing doesn't stop the import.
- **Manage photos dialog** (`<.modal>`): one row per photo with a drag handle, thumbnail, caption field, credit and license, status (Adding…, or Failed with the error and Retry) and Delete. Delete opens "Delete photo" ("Its files are removed from storage." / "This can't be undone.", Danger action "Delete photo"). Both dialogs fit the 34rem modal.

Waits, beyond the facts-model rows in the scope table: Oak Compendium's write-up fragment and reader, and the field marks table with other sources behind a disclosure.

Data fix, applied to production 2026-11-25 through the import endpoint (`import_id` `preferred-sources-2026-11-25`, 421 updates): every species with no Oak Compendium text and no preferred row now prefers Oaks of the World, or its only other source with text (Sibley on *graciliformis* and *vacciniifolia*); seven hybrids whose preferred row was an empty Oak Compendium row now prefer Oaks of the World; five species with Oak Compendium text and no preferred row now prefer Oak Compendium. Left as they were: × *guadalupensis* (prefers the Botanical Gazette article) and × *prasina* (one empty row). The app doesn't maintain the flag when source data is added or deleted; the source order above still gives a sensible default when it is missing.

## Phase 5: Editor UI

- Port `InatImportComponent` (`lib/gallformers_web/live/admin/inat_import_component.ex`) as the Add photos dialog designed in Phase 4 (`design/prototype/species-today.html`, Dialog states), opened from the species page by editors: paste an observation URL or ID, load it, pick photos, import.
- All Rights Reserved with permission (Jeff, 2026-11-25): Phase 3's import context currently rejects All Rights Reserved photos. Change it to accept one only with a permission confirmation the server records with the photo (a migration adding, for example, who confirmed and when), and reject it without one. The dialog's confirmation box sends it; the server never infers it. The public credit reads "All rights reserved, used with the creator's permission". iNat sends no license code for All Rights Reserved, so a photo with none is stamped "All rights reserved"; one with a code we don't recognise is flagged "No license given" in the dialog. Both follow the same confirmation and are stored as All Rights Reserved with it (Jeff, 2026-11-25). Update Phase 3's tests for the new rule.
- The Manage photos dialog, as Phase 4 designs it: captions, drag to reorder (port `sortable_images.js`) and delete, with the Delete photo confirmation. The title row's Edit menu item notes failed imports ("Manage photos… 1 failed"). Show pending/ready/failed state, per-photo errors, already-imported results and retry for failures. Reopening the dialog restores progress from persisted records.
- The dialog is `<.modal>` and the entry points are `<.edit_menu>` items, per CODING_STANDARDS.md.
- Every write handler checks `socket.assigns[:current_scope]`, including import and retry. Resolve image IDs against the current species for caption, reorder and delete; reject forged IDs or photo selections. Never trust client-supplied license, attribution or uploader values.

Done when an editor can import, retry, reorder, caption and delete photos from the species page in dev, partial failures are understandable, and unauthorized or forged events cannot write or enqueue work.

**Status: done.** Jeff approved the Add photos and Manage photos dialogs in dev on 2026-11-25.

## Phase 6: Carousel

- Build the photo viewer designed in Phase 4 (`design/prototype/photo-viewer.css` and `photo-viewer.js`): the stage with caption, credit, license and iNaturalist link, and a thumbnail rail that shows five at a time (six on phones) with step buttons that page through the rest, a count, and Left/Right keys. Many species will have a dozen or more photos.
- It is a shared component that will move back to gallformers (Jeff, 2026-11-25): a function component plus one self-contained JS hook and its own CSS, themed by custom properties, with no Oaks-specific dependencies in its markup, script or styles. Take the lightbox, swipe and details dialog from gallformers' `photo_viewer/1` (`lib/gallformers_web/components/domain_components.ex`) and `photo_viewer.js`, with its test.
- Medium variant on the stage, small for thumbnails. An All Rights Reserved photo's credit says it is used with the creator's permission.
- Display only ready images. Cover zero, one and many photos; no pending or broken-variant placeholders. With no photos the column reads "No photos yet." (hidden on phones).
- Add it to `dev_components_live.ex`.

Done when the component shows imported photos with credit and license, and the keyboard, swipe, lightbox and details dialog all work.

**Status: done.** Jeff approved the viewer in `/dev/components` on 2026-11-25. The shared component is `OaksWeb.PhotoViewer.photo_viewer/1` (hook `assets/js/photo_viewer.js`, `pv-` block in `assets/css/system/components.css`); pages use `<.species_photos>` (DesignComponents), which shows a species' ready photos (medium on the stage, small in the rail, large full size) and themes the viewer with `.oc-photos`. Moves wrap at both ends. The details dialog lists caption, creator, license and source; the uploader and last-changed-by fields hold editors' emails, so Oaks never passes them. The hook was verified in a browser with Playwright (keys, steps and count, mouse and touch swipe, lightbox, details dialog, focus return); there is no JS test runner. The viewer has since moved to heartwood_ui as `Heartwood.UI.PhotoViewer` (v0.2.0, with a filmstrip in place of the rail; docs/facts-expansion/architecture-groundwork.md, section 3, step 2c).

## Phase 7: Species page rebuild

- Rebuild `species_detail_live.ex` on the Phase 4 design (`design/prototype/species-today.html` and the Phase 4 decisions): two columns, the photo viewer in the left column, and every section the scope table marks built or kept. The prototype is the visual reference; the build uses the component library, per AGENTS.md.
- New pieces go into the library first, each in `/dev/components` for Jeff's review before the page uses it: likely the source tabs (with the one icon link per open tab) and the hybrid rows.
- Source order and the default tab live in the context, not the template: the preferred source, then Oak Compendium, then Oaks of the World, then the rest by name; the page opens on the first with any text. The same order picks the title's common name. Never show "preferred".
- Changes from today's page: the source tabs lose the "Data from …" header and the "preferred" note; the per-source Edit menu moves beside the tabs; Closely related is no longer shown; a hybrid's parents move to the title row's subtitle; the not-covered notice appears when there is no Oak Compendium text; Synonyms, Subspecies and varieties, Hybrids, External links, Sources and the cite line follow the main content in that order; the Edit menu gains Add photos from iNaturalist… and Manage photos….
- Check every preserved field, relationship, link and editor action against the Phase 4 scope table. Keep stored fields and the public API intact; update merge/delete integration as required by Phase 3.

Done when the species page matches the approved design at desktop, tablet and phone widths, the sections that wait for the facts model are listed in this plan, and `make done-checks` passes.

**Status: done.** Jeff approved the library pieces in `/dev/components` and the page in dev on 2026-11-25. The library gained `photo_columns`, `source_tabs` (with the `Tablist` hook), `ruled_rows`, `hybrid_rows`, `comma_list`, `not_covered_notice` and `cite_line` (DesignComponents), the title row's `:common_name` slot and `patch` on `source_mark`. Tabs that don't fit scroll sideways with a fade and the actions wrap above them, so the ochre underline sits just above the rule (Jeff, 2026-11-25). The source order, default tab, common name, coverage, hybrids' other parents and the band's siblings live in `Oaks.Species`. The open tab is in the address as `?source=<source id>`, which the common name's source mark uses. The siblings menu lists the non-hybrid species at the taxon's last rank (a variety's: its species' varieties), twelve around the current one, with a link to the group's page. A hybrid with no recorded parent reads "Hybrid of unrecorded parents", as in the prototype. The sections that wait are in the scope table and under the Phase 4 decisions.

## Acceptance checks

Use `Req.Test` for iNat, a failure-capable storage/invalidation mock, and real fixture bytes with the Local adapter for resizing. Tests assert outcomes, not task timing; simulate restarts from persisted work and synchronize on completion.

| Area | Required evidence |
|---|---|
| Imports | Original plus four usable variants and full attribution before publication; repeated/concurrent imports produce one row per species/photo; pending/failed photos stay private |
| Failure and recovery | Download, resize, partial upload and ready-state commit failures; restart after files are stored; partial batches retain successes; retry uses fresh paths; cleanup is durable; disconnect/reopen restores progress |
| Merge | Unique photos append in order, target duplicates/captions win and are previewed, pending/failed imports move safely, rollback preserves files, duplicate cleanup cannot remove retained images |
| Removal | Photo/species deletion records all files before removing rows; storage and invalidation failures retry across restart; active imports cannot recreate deleted files; re-import is safe |
| Authorization | Logged-out import/retry/caption/reorder/delete events write nothing; forged cross-species IDs and disallowed photo selections are rejected; missing/unknown/All Rights Reserved licenses cannot be imported without the recorded permission confirmation |
| Image processing and carousel | Real decoding/resizing through Local produces all four sizes; zero/one/many photos; attribution, keyboard, swipe, lightbox and details dialog |
| Page regression | Every retained field/link/action remains reachable; per-field fallback with absent/blank Oak Compendium data and stable ties; full text retained; source comparison and synonym/not-found behavior preserved |
| Design | Desktop/tablet/phone review of full, sparse, other-source-only, hybrid and variety pages, with no invented review marks or look-alike claims; Impeccable finish review |
| Production wiring | Private origin and custom-domain delivery; live object survives lifecycle rules; deletion plus completed invalidation stops fresh delivery; 30-day noncurrent expiration configured |

Run `make done-checks` inside the Nix dev shell before handing implementation over. Record the AWS smoke checks separately; mocks do not establish production permissions or cache behavior.

### Production smoke checks

Run against AWS, apart from the mock-based tests above. Details are in `infra/README.md`.

- **Private origin and custom-domain delivery** (2026-11-24, with a throwaway upload key, deleted afterwards): an object put with the upload key is served from `https://images.oakcompendium.org` (a Miss, then a Hit). The same object straight from S3 is a 403, plain HTTP is a 403, and the domain's root lists nothing. The upload key can't read objects.
- **Deletion plus completed invalidation stops fresh delivery** (2026-11-24): after deletion the CDN kept serving the object until an invalidation of its path, made with the upload key, completed; then a fresh request was a 403. The app's `Oaks.Storage.S3`, run from dev, did the same for an original and its four variants. Repeated deletes succeeded, and a repeated invalidation with the same caller reference returned the same ID.
- **Lifecycle** (2026-11-24): the bucket's lifecycle has three rules: expire noncurrent versions 30 days after they become noncurrent, remove expired delete markers, abort multipart uploads after 7 days. No rule expires current objects, so live images survive; that is a check of the configuration, since expiry can't be watched in less than 30 days. Versioning is on and all public access is blocked.
- **Infrastructure matches its code** (2026-11-25): `tofu plan` reports no changes for every resource, the images bucket, lifecycle, policy, distribution and upload user included.
- **Upload key in Fly** (2026-11-25): a new key for `oaks-images-upload`, the user's only one, is kept in 1Password (`infra/README.md`) and staged in Fly secrets as `IMAGES_AWS_ACCESS_KEY_ID` and `IMAGES_AWS_SECRET_ACCESS_KEY`. They take effect at the deploy that follows the merge to main.
- **Design:** an Impeccable finish review of the rebuilt species page was run; its notes weren't kept (Jeff, 2026-11-25).
- **After the merge to main deploys:** import a photo on a species page in production, check that its files are served from `images.oakcompendium.org`, then delete it and check that its cleanup finishes and the files are a 403.
