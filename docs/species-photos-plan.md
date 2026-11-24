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

- `s3.tf`: the `oaks-images` bucket, versioned, all public access blocked, with a bucket policy that lets only the distribution read (OAC).
- `cloudfront.tf`: the OAC, and a distribution with the alias `images.oakcompendium.org`, HTTPS only and a long cache TTL. Image paths are unique per import, so cached files never need clearing.
- `acm.tf`: a certificate for `images.oakcompendium.org` in us-east-1, with DNS validation. Outputs give the validation CNAME and the distribution's domain for Jeff to add to DNS.
- `iam.tf`: the `oaks-images-upload` user, allowed only `s3:PutObject`, `s3:DeleteObject` and `s3:ListBucket` on the images bucket. Its access key goes into Fly secrets.

Done when an object put with the upload key is served from `https://images.oakcompendium.org/...`.

## Phase 2: Storage layer

- Deps: `ex_aws`, `ex_aws_s3`, `sweet_xml`, `hackney` and `image` (libvips, which the flake and the Dockerfile need). Make `req` a runtime dep.
- Config: `config :oaks, :images` with the adapter, bucket and `cdn_url`. `runtime.exs` reads the keys from env. Test uses a mock adapter.
- `Oaks.Storage.Images` is the API: `put/3`, `delete/1`, `list/1`, `public_url/1`, `variant_url/2`. Paths are `species/{id}/{id}_{ts}_{uniq}_original.{ext}`. Port from `lib/gallformers/storage/images.ex`.
- Adapters: `S3`, ported from `lib/gallformers/storage/s3.ex`; and `Local`, which writes to `tmp/images` and is served by `Plug.Static` at `/dev-images` in dev only.
- Variants: `generate_size_variants/2` with `Image`, run in a Task once the original is stored.

Done when dev and prod can both store an image, make its variants and serve it.

## Phase 3: iNat client and data

- Port `Gallformers.INaturalist` with its `Observation` and `Photo` structs: `parse_observation_id/1` (a URL or an ID), `fetch_observation/1`, `download_photo/1`, `map_license/1`, `format_creator/2`. Tests stub iNat with `Req.Test`.
- Port `Gallformers.Licenses` and `Gallformers.Images.Attribution`.
- Migration for the `images` table: `species_id` (FK), `path`, `sort_order`, `caption`, `creator`, `license`, `licenselink`, `sourcelink`, `inat_observation_id`, `inat_photo_id`, `uploader`, `lastchangedby`, timestamps. Unique on (`species_id`, `inat_photo_id`).
- `Oaks.Images`: `list_for_species/1`, `import_inat_photo/4` (download, store, create the row, start the variants), `update_caption/3`, `reorder/2`, `delete/1` (removes every variant). Port from `lib/gallformers/images.ex`.
- All Rights Reserved photos can't be imported.

Done when, in tests, an observation becomes stored images with full attribution.

## Phase 4: Species page design for today's data

Work with Impeccable (`impeccable:impeccable`) to adapt the taxon page prototype to the data the site has now. This is Large work: the full process, with Impeccable's decision page and Jeff's choices, before any build. The result is an updated prototype in `design/prototype/` and the decisions recorded in this plan.

What today's data can and can't fill (a starting point for the design, not a layout):

| Prototype section | Today's data | This plan |
|---|---|---|
| Taxonomy band, title row, IUCN stamp | Already built | Kept |
| Siblings menu in the band | Taxonomy | Built |
| Common name in the title | Sources' local names, Oak Compendium first | Built |
| Photos and carousel | The images from Phases 3 and 5 | Built |
| Jeff's write-up (fragment and reader) | Oak Compendium's text, by field | Built if the design keeps it; the reader is a new library component |
| Hybrids, each with its other parent | `hybrids`, `parent1`, `parent2` | Built |
| Look-alikes | `closely_related_to`, names only | Partly: no "why" note, no Compare |
| Field marks table | One source field per trait | Mostly: other sources show as not reviewed |
| Range | Each source's range text | Partly: text per source, the map's place reserved; no place list, no native or introduced |
| Name and synonyms | `synonyms` | Partly: no accepted or misapplied status |
| Sources and cite-this-page line | The species' sources | Built |
| Link to the source comparison | `SpeciesCompareLive` | Built |
| What sets it apart (ranked traits) | None | Waits for the facts model |
| Agree, differs and unreviewed marks | None | Waits for the facts model |
| Taxon comparison (`?vs=`) | None | Waits for the facts model |
| The page in the 1400px frame, three columns | | Built |

Open questions for the design pass, not to be settled by a build:

- What the reading column holds while there are no distinguishing traits.
- Whether Oak Compendium's text stands in for Jeff's write-up, and how the page says what it is.
- Where editors manage photos (captions, order, delete): a dialog on the species page or elsewhere.
- How look-alikes, field marks, range and synonyms read honestly with the data they lack.
- The add-observation dialog, starting from the Observation panel in `design/prototype/id-mode.html` (URL and Load, the photo strip, the observation's meta line).

Done when Jeff has approved the adapted prototype and its decisions are written here.

## Phase 5: Editor UI

- Port `InatImportComponent` (`lib/gallformers_web/live/admin/inat_import_component.ex`) as the add-observation dialog designed in Phase 4, opened from the species page by editors: paste an observation URL or ID, load it, pick photos, import. All Rights Reserved photos are shown but can't be picked.
- Manage the photos already imported where Phase 4 puts it: captions, drag to reorder (port `sortable_images.js`) and delete.
- The dialog is `<.modal>` and the entry points are `<.edit_menu>` items, per CODING_STANDARDS.md.
- Every write handler checks `socket.assigns[:current_scope]`.

Done when an editor can import, reorder, caption and delete photos from the species page in dev.

## Phase 6: Carousel

- Port `photo_viewer/1` from `lib/gallformers_web/components/domain_components.ex` into `design_components.ex`, and `photo_viewer.js` with its test. Restyle it to DESIGN.md (photo frames, Second Stock thumbnails, pencil source marks) rather than gallformers' look.
- Medium variant on the stage, small for thumbnails, credit and license under each photo.
- Add it to `dev_components_live.ex`.

Done when the component shows imported photos with credit and license, and the keyboard, swipe, lightbox and details dialog all work.

## Phase 7: Species page rebuild

- Rebuild `species_detail_live.ex` on the Phase 4 design: the carousel in its place, and every section the scope table marks built.
- New pieces go into the library first, each in `/dev/components` for Jeff's review before the page uses it: likely the write-up fragment and reader, the look-alike and hybrid rows, the field marks table and the range list.
- The source tabs give way to the field marks table and the link to the source comparison.
- Update the API or other pages only if they read what the page drops.

Done when the species page matches the approved design at desktop, tablet and phone widths, the sections that wait for the facts model are listed in this plan, and `make done-checks` passes.
