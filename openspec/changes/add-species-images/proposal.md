# Change: Add Species Images

## Prerequisites

- **add-table-ids**: Add integer IDs to `taxa` and `oak_entries` tables - The images table uses `species_id` as FK

## Why

The Oak Compendium is designed as a digital field guide for oak identification. Text descriptions alone are insufficient for reliable identification in the field. Users need visual references showing bark, leaves, acorns, buds, growth form, and other diagnostic features to confidently identify oak species.

## What Changes

### New Capability: Image Management System

- **Database**: New `images` table storing metadata for species photos
- **Storage**: AWS S3 bucket with CloudFront CDN for image hosting
- **API**: New endpoints for image upload, import from iNaturalist, and metadata management
- **Web UI**: Gallery component on species pages, admin upload interface, lightbox viewer

### Key Features

1. **Image Categories** (fixed list): habitat, growth form, bark, leaf shape, upper/lower leaf vestiture, buds, twigs, twig vestiture, acorns, flowers, fall color
2. **Hero Image**: User-designated primary image per species
3. **Multi-size Processing**: Generate thumbnail (200px), medium (800px), large (1600px), preserve original (JPEG, PNG, WebP)
4. **Two Upload Paths**: Direct upload via presigned S3 URL, or import from URL (iNaturalist, etc.) via Lambda
5. **iNaturalist Integration**: Import images by pasting observation URL, auto-populate attribution, batch select from multi-photo observations
6. **Attribution Tracking**: Photographer, license, source URL, date, location, notes, permission record
7. **Gallery UI**: Filterable by category, mobile-friendly carousel, GLightbox for full-size viewing, accessible (alt text, keyboard nav)

### Target Scale

~10,000 images over 3-5 years (~700 species × 10-20 images each)

## Impact

- **Affected specs**: `api-server` (new image endpoints)
- **New specs**: `web-images` (gallery UI, upload interface)
- **Affected code**:
  - `api/internal/` - new handlers, S3 client, image processing
  - `api/internal/db/` - new images table and queries
  - `web/src/lib/components/` - gallery, upload, lightbox components
  - `web/src/routes/` - admin upload integration on species detail page
- **Infrastructure**:
  - AWS S3 bucket (`oak-compendium-images`)
  - CloudFront distribution
  - AWS Lambda for image processing (triggered by S3 upload or direct API invoke for URL imports)
  - IAM credentials for API server (S3 + Lambda invoke) and Lambda (S3 + API callback)

## Out of Scope

- Cross-species image search/browse UI (data model supports it, UI deferred)
- Identification tool integration (future feature)
- Batch upload from folder (start with single image upload)
- Video support
