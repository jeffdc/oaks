# Species photos

Add photos to species, imported only from iNaturalist, stored in S3, served through CloudFront on `images.oakcompendium.org`, and shown in the gallformers carousel. The model is gallformers on the `taxogall` branch; "port" below means copy from there and adapt.

The plan also rebuilds the species page on the redesign's taxon page (`design/prototype/shumardii.html`, brief in `.impeccable/surfaces/design-prototype-shumardii-html.md`, rules in DESIGN.md), as far as today's data allows, and lets an editor add an iNat observation's photos from that page. Parts of the prototype need the compendium's facts model, which doesn't exist yet; the scope table in Phase 4 says what this plan builds and what waits.

## Decisions

- Photos come only from iNat observations. Browser and phone uploads are out of scope.
- The S3 bucket is private. CloudFront reads it through Origin Access Control (OAC) and serves it on the custom domain `images.oakcompendium.org`, with an ACM certificate in us-east-1. Jeff updates DNS.
- Variants: small 300, medium 800, large 1200 and xlarge 2000 px, plus the original.
- Dev uses a local storage adapter with no AWS credentials.
- AWS is managed with OpenTofu, its state in S3, as in gallformers. Fly stays managed with `fly.toml` and `fly secrets`.
- CSP needs no change: `img-src` already allows `https:` (`lib/oaks_web/plugs/security_headers.ex`).
- The species page follows the redesign's taxon page, adapted with Impeccable to the data that exists today (Phase 4). The adaptation is a real design pass, not a cut-down build of the prototype.
- Editors add photos from the species page itself, not the species edit page.
- Every photo imported here is an exemplar photo. The other observation roles in the compendium plan (evidence, material, trait illustration) are out of scope.
- Imports have pending, ready and failed states. Only ready photos are public, after the original and all four variants are stored. Successful photos survive a partial batch failure; interrupted work is recoverable and retries do not duplicate photos.
- Merging species appends the source's photos after the target's. For duplicate iNat photo IDs, the target's photo and caption win; the merge preview shows this. Deleting a photo or species hides its photos at commit and schedules storage cleanup after commit.
- Removal includes deleting the original and every variant and invalidating their CloudFront paths, with retries. Deleted S3 versions are retained for 30 days before lifecycle cleanup; current live images do not expire.
- The rebuild preserves all existing content, relationships, links and editor actions. Phase 4 decides their placement. `closely_related_to` is labelled "Closely related"; all agreement and review-status marks wait for the facts model.
- Where one value is needed, select a nonempty value per field: Oak Compendium, then a preferred source, then remaining sources in stable order. Always identify the supplying source; keep other sources' values accessible. Phase 4 defines the exact display contract below.

## Phase 0: Infra baseline

`infra/` describes resources made by hand. It has never been applied and has no state.

1. Add `opentofu` to `flake.nix`.
2. Create the state bucket `oaks-terraform-state` by hand (versioned, encrypted). Add an `s3` backend with `use_lockfile = true`. Move to AWS provider 6.x and tofu 1.10 or later.
3. Remove the `fly` provider, `fly_app`, `fly_volume` and the `secret_key_base` variable.
4. Run `tofu import` on the Litestream bucket and its versioning, lifecycle and public-access-block settings, and on the IAM user, policy, attachment and access key.
5. Add `infra/README.md` listing the resources and how to run tofu.

Done when `tofu plan` shows no changes. Jeff runs steps 2 and 4 against AWS, or OKs Claude running them.

## Phase 1: Images infra

New files, split as gallformers does:

- `s3.tf`: the `oaks-images` bucket, versioned, all public access blocked, with a bucket policy that lets only the distribution read (OAC). Lifecycle expires noncurrent versions after 30 days and removes expired delete markers; it does not expire current live objects. The 30 days start when a version becomes noncurrent, not when the photo was imported; AWS performs expiration asynchronously ([S3 lifecycle](https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-expire-general-considerations.html)).
- `cloudfront.tf`: the OAC, and a distribution with the alias `images.oakcompendium.org`, HTTPS only and a long cache TTL. Image paths are unique per import attempt. Removal invalidates every path after storage deletion; unique paths do not evict cached removals ([CloudFront invalidation](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Invalidation.html)).
- `acm.tf`: a certificate for `images.oakcompendium.org` in us-east-1, with DNS validation. Outputs give the validation CNAME and the distribution's domain for Jeff to add to DNS.
- `iam.tf`: the `oaks-images-upload` user, allowed `s3:PutObject`, `s3:DeleteObject` and `s3:ListBucket` on the images bucket, plus `cloudfront:CreateInvalidation` and `cloudfront:GetInvalidation` on this distribution. Its access key goes into Fly secrets; the distribution ID goes into runtime configuration. Permanent version expiration is handled by the bucket lifecycle.

Done when an object put with the upload key is served from `https://images.oakcompendium.org/...`, deletion plus completed invalidation stops a fresh request serving it, and the plan includes the 30-day noncurrent-version lifecycle without expiring live images.

## Phase 2: Storage layer

- Deps: `ex_aws`, `ex_aws_s3`, `sweet_xml`, `hackney` and `image` (libvips, which the flake and the Dockerfile need), plus a CloudFront API client for invalidation. Make `req` a runtime dep.
- Config: `config :oaks, :images` with the adapter, bucket, `cdn_url` and distribution ID. `runtime.exs` reads the keys from env. Test uses a mock adapter for failure cases and Local for real image processing.
- `Oaks.Storage.Images` is the API: `put/3`, `delete/1`, `list/1`, `public_url/1`, `variant_url/2`. Paths are `species/{id}/{id}_{ts}_{uniq}_original.{ext}`. Port from `lib/gallformers/storage/images.ex`.
- Adapters: `S3`, ported from `lib/gallformers/storage/s3.ex`; and `Local`, which writes to `tmp/images` and is served by `Plug.Static` at `/dev-images` in dev only.
- Add an invalidation boundary with submit and completion checks; Local completes it as a no-op. Persist the invalidation ID so a restart can resume checking it.
- Variants: adapt `generate_size_variants/2` to process original bytes with `Image` and return the generated variants only after all sizes succeed. The Phase 3 worker stores the original and variants. Do not port gallformers' CDN re-download, fixed sleep or fire-and-forget resize tasks: none establishes readiness, and a dev URL is not a storage read API.

Done when dev and prod can both store an image, make its variants and serve it, real resizing is tested through Local, and storage/invalidation failures can be injected through the mock.

## Phase 3: iNat client and data

- Port `Gallformers.INaturalist` with its `Observation` and `Photo` structs: `parse_observation_id/1` (a URL or an ID), `fetch_observation/1`, `download_photo/1`, `map_license/1`, `format_creator/2`. Tests stub iNat with `Req.Test`.
- Port `Gallformers.Licenses` and `Gallformers.Images.Attribution`.
- Migration for the `images` table: `species_id` (FK), `path`, `sort_order`, `caption`, `creator`, `license`, `licenselink`, `sourcelink`, `inat_observation_id`, `inat_photo_id`, `uploader`, `lastchangedby`, `status` (`pending`, `ready`, `failed`), last import error, timestamps. Require the iNat IDs and enforce uniqueness on (`species_id`, `inat_photo_id`) across all states. The FK must not silently cascade away photos without recording cleanup.
- Persist import attempts and cleanup operations in SQLite, including their object paths, attempt identity, retry information and invalidation ID. Cleanup records survive deletion of their image and species; a running Task is not the record of outstanding work.
- `Oaks.Images`: `list_for_species/1` returns ready photos in order; a separate editor query includes pending and failed imports. Adapt `import_inat_photo/4` to reserve the row and enqueue work; add retry and progress queries. Keep `update_caption/3`, `reorder/2` and `delete/1`, with the transaction and cleanup rules below. Port the useful pieces from `lib/gallformers/images.ex`.
- All Rights Reserved photos, including missing or unknown licenses mapped to that value, are rejected by the import context as well as disabled in the UI. Attribution comes from server-fetched observation/photo data; species ownership and uploader come from the current species and authenticated editor on the server.

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

## Phase 4: Species page design for today's data

Work with Impeccable (`impeccable:impeccable`) to adapt the taxon page prototype to the data the site has now. This is Large work: the full process, with Impeccable's decision page and Jeff's choices, before any build. The result is an updated prototype in `design/prototype/` and the decisions recorded in this plan.

What today's data can and can't fill (a starting point for the design, not a layout):

| Prototype section | Today's data | This plan |
|---|---|---|
| Taxonomy band, title row, IUCN stamp | Already built, including scientific name and author | Kept |
| Siblings menu in the band | Taxonomy | Built |
| Common name in the title | Sources' local names | Built using the per-field selection rule below; retain all names with their sources |
| Photos and carousel | The images from Phases 3 and 5 | Built |
| Jeff's write-up (fragment and reader) | Oak Compendium's text, by field | Built if the design keeps it; the reader is a new library component |
| Hybrids, each with its other parent | `hybrids`, `parent1`, `parent2` | Built |
| Parents of a hybrid | `parent1`, `parent2` | Kept, including when only one parent is known |
| Subspecies and varieties | `subspecies_varieties` | Kept |
| Closely related | `closely_related_to`, names only | Kept under this label; no inferred visual similarity, "why" note or Compare |
| Field marks table | `growth_habit`, `leaves`, `flowers`, `fruits`, `bark`, `twigs`, `buds` per source | Built with sourced values; no agreement or review-status marks |
| Hardiness and habitat; additional information | `hardiness_habitat`, `miscellaneous` per source | Kept in full with attribution; Phase 4 decides placement |
| Range | Each source's range text | Partly: text per source, the map's place reserved; no place list, no native or introduced |
| Name and synonyms | `synonyms` | Partly: no accepted or misapplied status |
| Sources and cite-this-page line | The species' sources | Built |
| Original-source and external links | Each source row's `url`, species `external_links`, computed links | Kept |
| Species editor actions | Edit, delete, make synonym of another species, add source data | Kept; merge/delete include photos |
| Per-source editor actions | Edit source data, delete source data | Kept and reachable after source tabs are removed |
| Link to the source comparison | `SpeciesCompareLive` | Built |
| What sets it apart (ranked traits) | None | Waits for the facts model |
| Look-alike claims | No explicit visual-similarity data | Waits; closely related names are not relabelled as look-alikes |
| Agree, differs and unreviewed marks | None | Waits for the facts model |
| Taxon comparison (`?vs=`) | None | Waits for the facts model |
| The page in the 1400px frame, three columns | | Built |

Data display contract:

- For each field independently, skip nil, empty and whitespace-only values. Choose Oak Compendium (source 3) first, then rows marked `is_preferred`, then remaining sources. Break ties by ascending source ID. For common names, skip sources whose parsed list has no nonempty name, and use the first nonempty name in the chosen source's stored list for the title.
- Keep the supplying source attached to every displayed value. Other sources' nonempty values and all common names remain accessible with attribution; a fallback value never appears as Jeff's text. Preserve full stored text and Markdown, even if an excerpt opens a reader.
- If no source supplies a field, omit that field or use the approved empty-state wording; never invent a value or a review status. A missing Oak Compendium write-up has no substitute attributed to Jeff.
- Preserve source comparison, synonym redirects, real not-found responses and all existing editor actions. This is a presentation change, not removal of stored fields or changes to the public API.

Open questions for the design pass, not to be settled by a build:

- What the reading column holds while there are no distinguishing traits.
- Whether Oak Compendium's text stands in for Jeff's write-up, and how the page says what it is.
- Where editors manage photos (captions, order, delete): a dialog on the species page or elsewhere.
- Where the preserved content and editor actions fit, and how closely related names, field marks, range and synonyms read with the data available.
- The add-observation dialog, starting from the Observation panel in `design/prototype/id-mode.html` (URL and Load, the photo strip, the observation's meta line).
- Empty and sparse states: no photos, one photo, many photos, pending/failed imports for editors, no Oak Compendium text, other-source-only data, no source data, a hybrid and a variety.

Done when Jeff has approved the adapted prototype, including sparse states and destinations for every preserved field/action, and its decisions are written here.

## Phase 5: Editor UI

- Port `InatImportComponent` (`lib/gallformers_web/live/admin/inat_import_component.ex`) as the add-observation dialog designed in Phase 4, opened from the species page by editors: paste an observation URL or ID, load it, pick photos, import. All Rights Reserved photos are shown but can't be picked.
- Manage the photos already imported where Phase 4 puts it: captions, drag to reorder (port `sortable_images.js`) and delete. Show pending/ready/failed state, per-photo errors, already-imported results and retry for failures. Reopening the dialog restores progress from persisted records.
- The dialog is `<.modal>` and the entry points are `<.edit_menu>` items, per CODING_STANDARDS.md.
- Every write handler checks `socket.assigns[:current_scope]`, including import and retry. Resolve image IDs against the current species for caption, reorder and delete; reject forged IDs or photo selections. Never trust client-supplied license, attribution or uploader values.

Done when an editor can import, retry, reorder, caption and delete photos from the species page in dev, partial failures are understandable, and unauthorized or forged events cannot write or enqueue work.

## Phase 6: Carousel

- Port `photo_viewer/1` from `lib/gallformers_web/components/domain_components.ex` into `design_components.ex`, and `photo_viewer.js` with its test. Restyle it to DESIGN.md (photo frames, Second Stock thumbnails, pencil source marks) rather than gallformers' look.
- Medium variant on the stage, small for thumbnails, credit and license under each photo.
- Display only ready images. Cover zero, one and many photos; no pending or broken-variant placeholders in the public carousel. Phase 4 decides the no-photo layout.
- Add it to `dev_components_live.ex`.

Done when the component shows imported photos with credit and license, and the keyboard, swipe, lightbox and details dialog all work.

## Phase 7: Species page rebuild

- Rebuild `species_detail_live.ex` on the Phase 4 design: the carousel in its place, and every section the scope table marks built or kept.
- New pieces go into the library first, each in `/dev/components` for Jeff's review before the page uses it: likely the write-up fragment and reader, the closely related and hybrid rows, the field marks table and the range list.
- The source tabs give way to the field marks table and the link to the source comparison.
- Check every preserved field, relationship, link and editor action against the Phase 4 scope table. Keep stored fields and the public API intact; update merge/delete integration as required by Phase 3.

Done when the species page matches the approved design at desktop, tablet and phone widths, the sections that wait for the facts model are listed in this plan, and `make done-checks` passes.

## Acceptance checks

Use `Req.Test` for iNat, a failure-capable storage/invalidation mock, and real fixture bytes with the Local adapter for resizing. Tests assert outcomes, not task timing; simulate restarts from persisted work and synchronize on completion.

| Area | Required evidence |
|---|---|
| Imports | Original plus four usable variants and full attribution before publication; repeated/concurrent imports produce one row per species/photo; pending/failed photos stay private |
| Failure and recovery | Download, resize, partial upload and ready-state commit failures; restart after files are stored; partial batches retain successes; retry uses fresh paths; cleanup is durable; disconnect/reopen restores progress |
| Merge | Unique photos append in order, target duplicates/captions win and are previewed, pending/failed imports move safely, rollback preserves files, duplicate cleanup cannot remove retained images |
| Removal | Photo/species deletion records all files before removing rows; storage and invalidation failures retry across restart; active imports cannot recreate deleted files; re-import is safe |
| Authorization | Logged-out import/retry/caption/reorder/delete events write nothing; forged cross-species IDs and disallowed photo selections are rejected; missing/unknown/All Rights Reserved licenses cannot bypass the context |
| Image processing and carousel | Real decoding/resizing through Local produces all four sizes; zero/one/many photos; attribution, keyboard, swipe, lightbox and details dialog |
| Page regression | Every retained field/link/action remains reachable; per-field fallback with absent/blank Oak Compendium data and stable ties; full text retained; source comparison and synonym/not-found behavior preserved |
| Design | Desktop/tablet/phone review of full, sparse, other-source-only, hybrid and variety pages, with no invented review marks or look-alike claims; Impeccable finish review |
| Production wiring | Private origin and custom-domain delivery; live object survives lifecycle rules; deletion plus completed invalidation stops fresh delivery; 30-day noncurrent expiration configured |

Run `make done-checks` inside the Nix dev shell before handing implementation over. Record the AWS smoke checks separately; mocks do not establish production permissions or cache behavior.
