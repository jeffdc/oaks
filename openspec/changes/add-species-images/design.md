# Design: Add Species Images

## Context

The Oak Compendium needs species images for field identification. Images will come from two sources:
1. Direct uploads (user's own photos)
2. iNaturalist observations (with proper attribution)

### Stakeholders
- Primary user: Project owner (admin, only person uploading images)
- End users: Anyone browsing the field guide (public read access)

### Constraints
- Must handle ~10,000 images at maturity
- Must preserve originals for future re-processing
- Mobile-friendly gallery experience required

### Prerequisites
- **Add Primary Key IDs to Core Tables** (proposal TBD) - The images table uses `species_id` as FK, requiring oak_entries to have an `id` column

## Goals / Non-Goals

### Goals
- Enable image upload and display for all species
- Track full attribution for licensing compliance
- Optimize images for fast mobile loading
- Support filtering by image category (bark, leaves, etc.)

### Non-Goals
- User-generated content moderation (admin-only uploads)
- Image editing/cropping in-browser
- Social features (comments, likes)
- AI-based image recognition

## Decisions

### 1. Storage: AWS S3 + CloudFront

**Decision**: Store images in S3, serve via CloudFront CDN.

**Alternatives Considered**:
- Fly.io volume: Simpler but limited storage, tied to single region
- GitHub repo: Size limits, bloats repo
- Cloudflare R2: Viable but user has existing AWS experience

**Rationale**: S3 is proven at scale, CloudFront provides edge caching globally, user already has AWS account.

### 2. Image Processing: Two Lambda Trigger Paths

**Decision**: Lambda handles all image processing via two trigger paths depending on upload source.

**Path A: Direct Upload (user's own photos)**
```
1. Client → API: Request upload URL for species X
2. API → Client: Presigned S3 URL + image ID + status: "pending"
3. Client → S3: Direct upload (bypasses API server)
4. S3 → Lambda: Triggered by S3 event on originals/ prefix
5. Lambda: Download from S3, generate sizes, upload processed versions
6. Lambda → API: Update status to "complete"
7. Client: Polls API until status is "complete"
```

**Path B: URL Import (iNaturalist, etc.)**
```
1. Client → API: POST /api/v1/images/import-url with image URL + metadata
2. API: Create image record with status "pending"
3. API → Lambda: Direct invoke via AWS SDK with image URL
4. Lambda: Download from URL, generate sizes, upload all to S3
5. Lambda → API: Update status to "complete"
6. Client: Polls API until status is "complete"
```

**Lambda distinguishes paths by**:
- S3 event: `event.Records[0].s3` exists → Path A
- Direct invoke: `event.imageUrl` exists → Path B

**Alternatives Considered**:
- Synchronous server-side: Fly.io has 10MB request limit, CPU-constrained
- API downloads for URL imports: Puts memory burden on Fly.io

**Rationale**: Presigned URLs bypass API size limits for direct uploads. Direct Lambda invoke for URL imports keeps heavy downloads off Fly.io. Lambda handles CPU-heavy work and scales automatically. Pay-per-use cost is negligible at our volume.

### 3. Upload Size Limit

**Decision**: 20MB maximum file size.

**Enforcement**:
- Client-side validation provides fast feedback
- Presigned URL includes `Content-Length` condition (max 20MB) - S3 rejects oversized uploads
- Lambda checks `Content-Length` header before downloading from URLs, rejects >20MB

**Rationale**: 20MB covers high-resolution JPEG/PNG images while keeping Lambda memory requirements reasonable (512MB). RAW files should be converted before upload.

### 4. Image Sizes

| Size | Longest Edge | Format | Use Case |
|------|--------------|--------|----------|
| thumb | 200px | WebP | Search results, grids |
| medium | 800px | WebP | Species page hero, inline |
| large | 1600px | WebP | Carousel, gallery browsing |
| original | As uploaded | Original (JPEG/PNG/WebP) | Detail zoom, archival |

**Note**: HEIC not supported (Sharp Lambda layer compatibility uncertain). Users should convert HEIC to JPEG before upload.

### 5. S3 Bucket Structure (Flat)

```
oak-compendium-images/
├── originals/{image_id}.{ext}
├── thumb/{image_id}.webp
├── medium/{image_id}.webp
└── large/{image_id}.webp
```

**Rationale**: Flat structure avoids issues with species name changes, simpler to manage.

### 6. Image Categories (Fixed List)

Categories in display/sort order (logical identification flow):

```
1. habitat
2. growth_form
3. bark
4. leaf_shape
5. upper_leaf_vestiture
6. lower_leaf_vestiture
7. buds
8. twigs
9. twig_vestiture
10. acorns
11. flowers
12. fall_color
```

Stored as JSON array field on image record. Images can have multiple categories.

**Sorting**: Hero image first, then remaining images ordered by their first category in the above order. Within a category, sorted by `created_at` ascending.

### 7. iNaturalist Integration

**Decision**: Client-side iNat API integration. Web app calls iNat directly; Lambda downloads images.

**Workflow**:
1. User pastes observation URL (e.g., `https://www.inaturalist.org/observations/123456`)
2. Web app extracts observation ID, calls iNat API directly from browser
3. Web app displays metadata (thumbnail, photographer, license, date, location) for user verification
4. For multi-photo observations, user can select multiple photos to import (batch select)
5. User confirms, selects categories (applied to all selected photos), optionally sets hero
6. Web app sends image URL(s) + metadata to Oak API (one request per image)
7. Oak API invokes Lambda directly with URL; Lambda downloads and processes

**Rationale**: Keeps iNat-specific API knowledge in the client (where it's needed for display). Lambda handles downloads to keep Fly.io lightweight.

**Rate Limits**: iNat allows ~1 req/sec, 10k/day. At our upload volume, no concern. If user hits rate limits, they see iNat error and retry.

### 8. Lightbox Library: GLightbox

**Decision**: Use GLightbox (vanilla JS, ~10KB) for full-size image viewing.

**Alternatives Considered**:
- PhotoSwipe: More features but larger bundle
- Svelte-specific libraries: No Svelte 5 compatibility confirmed
- Bigger Picture: Requires Svelte 4 compatibility mode

**Rationale**: GLightbox is lightweight, framework-agnostic (no Svelte 5 issues), well-maintained.

### 9. Database Schema

**Prerequisite**: This schema depends on oak_entries having an `id` column (see Prerequisites section).

```sql
CREATE TABLE images (
    id TEXT PRIMARY KEY,           -- UUID
    species_id INTEGER NOT NULL,   -- FK to oak_entries.id
    categories TEXT NOT NULL,      -- JSON array: ["bark", "leaves"]
    is_hero INTEGER DEFAULT 0,     -- boolean
    status TEXT DEFAULT 'pending', -- pending, processing, complete, failed

    -- Attribution
    creator TEXT NOT NULL,         -- Photographer name
    license TEXT NOT NULL,         -- cc-by, cc-by-nc, cc0, arr (all rights reserved)
    source_url TEXT,               -- iNat observation URL or null
    source_observation_id TEXT,    -- iNat observation ID if from iNat
    date_taken TEXT,               -- ISO date
    location_name TEXT,            -- "Santa Barbara, CA"
    latitude REAL,
    longitude REAL,
    caption TEXT,                  -- User notes
    permission_notes TEXT,         -- For ARR images: how permission obtained

    -- Storage
    original_filename TEXT,        -- Original uploaded filename
    original_format TEXT,          -- jpeg, png, webp (detected by Lambda, may differ from upload)
    original_width INTEGER,
    original_height INTEGER,
    s3_key_original TEXT,          -- originals/{id}.jpg
    s3_key_thumb TEXT,             -- thumb/{id}.webp
    s3_key_medium TEXT,            -- medium/{id}.webp
    s3_key_large TEXT,             -- large/{id}.webp

    -- Metadata
    created_at TEXT NOT NULL,      -- ISO timestamp
    updated_at TEXT NOT NULL,

    FOREIGN KEY (species_id) REFERENCES oak_entries(id) ON DELETE CASCADE
);

-- Note: ON DELETE CASCADE is safe because S3 cleanup is handled by application
-- before database deletion (species DELETE handler deletes S3 objects first).

CREATE INDEX idx_images_species ON images(species_id);
CREATE INDEX idx_images_hero ON images(species_id, is_hero);
```

### 10. API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/species/{name}/images` | List images for species |
| GET | `/api/v1/images/{id}` | Get image metadata (includes status for polling) |
| POST | `/api/v1/images/upload` | Create image record, return presigned S3 URL |
| POST | `/api/v1/images/import-url` | Import from external URL (Lambda processes) |
| PUT | `/api/v1/images/{id}` | Update metadata (categories, hero, caption) |
| DELETE | `/api/v1/images/{id}` | Delete image (removes from S3) |
| POST | `/api/v1/images/{id}/hero` | Set as hero image for species |
| PUT | `/api/v1/images/{id}/status` | Update status (called by Lambda) |

### 11. CloudFront URL Pattern

Images served at: `https://images.oakcompendium.com/{size}/{id}.{ext}`

Examples:
- `https://images.oakcompendium.com/thumb/abc123.webp`
- `https://images.oakcompendium.com/original/abc123.jpg`

### 12. CloudFront Configuration

- **CORS Origins**: `oakcompendium.org`, `www.oakcompendium.org`, `oakcompendium.com`, `www.oakcompendium.com`, `localhost:5173`
- **Cache TTL**: 1 year (images are immutable - new versions get new IDs)
- **Cache Invalidation**: Not needed - delete old image, upload new with new ID

### 13. Lambda Implementation: Node.js + Sharp

**Decision**: Implement the image processing Lambda in Node.js using the Sharp library.

**Alternatives Considered**:
- Go (pure Go, WASM, or CGO options): Pure Go and WASM ~5x slower than libvips; CGO requires complex Lambda cross-compilation
- Python + Pillow: Viable but slower than Sharp

**Rationale**: Sharp wraps libvips, a highly optimized C library for image processing. Benchmarks show Sharp outperforms Go's pure Go and WASM options by approximately 5x. Pre-built Lambda layers (cbschuld/sharp-aws-lambda-layer) provide ARM64-optimized binaries with ~7MB footprint, solving deployment complexity.

**Implementation Notes**:
- Runtime: Node.js 20.x (ARM64 architecture for cost efficiency)
- Layer: Use cbschuld/sharp-aws-lambda-layer or equivalent pre-built layer
- Memory: 512MB (sufficient for 20MB max upload size)
- Timeout: 60 seconds (buffer for cold starts)

**Lambda Behavior**:
- **Two trigger paths**: S3 event (check `event.Records[0].s3`) or direct invoke (check `event.imageUrl`)
- **URL download validation**: Check `Content-Type` header is image/jpeg, image/png, or image/webp before downloading
- **Download timeout**: 30 seconds max for URL downloads; mark as "failed:download_timeout" if exceeded
- **Size validation**: Check `Content-Length` header before downloading; reject >20MB
- **Format detection**: Use Sharp to detect actual format from magic bytes; correct S3 key extension if mismatched
- **Partial failure cleanup**: On any processing failure, delete any partial uploads (thumb, medium, large) before marking status as failed
- **Status update retry**: Retry API callback up to 3 times with exponential backoff

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| S3 costs at scale | At 10k images × 4 sizes × ~500KB avg = ~20GB. S3 cost: ~$0.50/month. Negligible. |
| CloudFront costs | At 100GB/month transfer = ~$8.50. Acceptable. |
| iNat API changes | We only use stable v1 endpoints. Store all metadata locally. |
| Original format variety | Accept JPEG, PNG, WebP only. Normalize to WebP for served sizes. |
| Lambda cold starts | Document expected delay in UI ("Processing may take 10-15 seconds"). |

## Known Limitations

These are accepted trade-offs for MVP simplicity:

| Limitation | Rationale |
|------------|-----------|
| Stale "pending" records | If upload abandoned, record stays pending forever. Manual cleanup if needed. |
| Duplicate images possible | No content hashing or URL deduplication. Admin deletes duplicates manually. |
| Hero race condition | Two simultaneous first-image uploads could both become hero. Unlikely with single admin; fix manually. |
| No monitoring/alerting | Deferred to future iteration. Lambda logs errors for manual review. |

## Migration Plan

No migration needed - this is a new capability. Database schema added via new table.

### Rollout Steps
1. Deploy API with new endpoints (images table created on first run)
2. Configure S3 bucket and CloudFront
3. Set IAM credentials as Fly.io secrets
4. Deploy web UI with gallery component
5. Begin uploading images

### Rollback
- Delete S3 bucket contents
- Drop `images` table
- Revert API and web deployments

## Open Questions

1. **RESOLVED**: Hero image selection → User explicitly sets via UI
2. **RESOLVED**: Image processing sync vs async → Asynchronous (presigned URL + Lambda)
3. **RESOLVED**: Format negotiation → WebP only for served sizes, original preserved
4. **DEFERRED**: Cross-species image search UI → Out of scope, data model supports it
