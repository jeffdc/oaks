# Tasks: Add Species Images

## Phase 1: Infrastructure Setup

- [ ] 1.1 Create S3 bucket `oak-compendium-images` in us-east-1
- [ ] 1.2 Configure bucket folders: `originals/`, `thumb/`, `medium/`, `large/`
- [ ] 1.3 Configure bucket CORS for presigned URL uploads from web app
- [ ] 1.4 Create CloudFront distribution pointing to S3 bucket
- [ ] 1.5 Configure CloudFront CORS (oakcompendium.org, www.oakcompendium.org, oakcompendium.com, www.oakcompendium.com, localhost:5173)
- [ ] 1.6 Configure CloudFront cache TTL (1 year)
- [ ] 1.7 Configure custom domain `images.oakcompendium.com` with SSL
- [ ] 1.8 Create IAM role for Lambda with S3 read/write permissions
- [ ] 1.9 Create IAM user for API server with S3 presigned URL, read permissions, and Lambda invoke permission
- [ ] 1.10 Store API server IAM credentials as Fly.io secrets
- [ ] 1.11 Configure S3 event trigger for Lambda on `originals/` prefix
- [ ] 1.12 Document Lambda ARN in Fly.io secrets for API server direct invoke

## Phase 2: Database Schema

**Prerequisite**: oak_entries must have `id` column (separate proposal TBD)

- [ ] 2.1 Add `images` table migration to API server (uses species_id FK, includes status field)
- [ ] 2.2 Create indexes for species_id, hero, and status queries
- [ ] 2.3 Add image repository/queries in `api/internal/db/`

## Phase 3: AWS Lambda - Image Processing (Node.js + Sharp)

- [ ] 3.1 Create Lambda function project (Node.js 20.x, ARM64)
- [ ] 3.2 Configure Sharp Lambda layer (cbschuld/sharp-aws-lambda-layer, pin version ARN)
- [ ] 3.3 Create separate Lambda API key and configure as environment variable
- [ ] 3.4 Set up SAM CLI for local Lambda testing
- [ ] 3.5 Implement two trigger paths: S3 event handler + direct invoke handler
- [ ] 3.6 Implement URL download with Content-Type validation (jpeg, png, webp only)
- [ ] 3.7 Implement Content-Length check before download (reject >20MB)
- [ ] 3.8 Implement download timeout (30 seconds max)
- [ ] 3.9 Implement image download from S3 originals/ (for S3 trigger path)
- [ ] 3.10 Implement format detection using Sharp magic bytes; correct extension if mismatched
- [ ] 3.11 Implement resize to 3 sizes using Sharp (200px, 800px, 1600px)
- [ ] 3.12 Implement WebP encoding using Sharp
- [ ] 3.13 Implement upload of processed images to S3
- [ ] 3.14 Implement partial upload cleanup on failure (delete thumb/medium/large before marking failed)
- [ ] 3.15 Implement API callback to update image status (with retry logic, 3 retries exponential backoff)
- [ ] 3.16 Add error handling and status update on failure (with failure reason)
- [ ] 3.17 Configure Lambda: 512MB memory, 60s timeout
- [ ] 3.18 Deploy Lambda and test with S3 trigger
- [ ] 3.19 Test Lambda with direct invoke (URL import path)

## Phase 4: API - Core Image Endpoints

- [ ] 4.1 Add S3 client wrapper in `api/internal/storage/` (presigned URLs with Content-Length condition, 1 hour expiry)
- [ ] 4.2 Add Lambda client wrapper in `api/internal/lambda/` (direct invoke for URL imports)
- [ ] 4.3 Implement `GET /api/v1/species/{name}/images` - list images (sorted: hero first, then by category order)
- [ ] 4.4 Implement `GET /api/v1/images/{id}` - get single image metadata (includes status)
- [ ] 4.5 Implement `POST /api/v1/images/upload` - create record, return presigned URL
- [ ] 4.6 Implement `PUT /api/v1/images/{id}` - update metadata
- [ ] 4.7 Implement `DELETE /api/v1/images/{id}` - delete image and S3 objects
- [ ] 4.8 Implement `POST /api/v1/images/{id}/hero` - set hero image
- [ ] 4.9 Implement `PUT /api/v1/images/{id}/status` - update status (called by Lambda)
- [ ] 4.10 Update species DELETE handler to cascade delete images (S3 + DB)
- [ ] 4.11 Update `GET /api/v1/species/{name}/full` to include images array

## Phase 5: API - URL Import

- [ ] 5.1 Implement `POST /api/v1/images/import-url` endpoint
- [ ] 5.2 Create image record with status "pending"
- [ ] 5.3 Invoke Lambda directly with image URL (Lambda downloads and processes)
- [ ] 5.4 Return image ID for client polling

## Phase 6: API - Testing & Deployment

- [ ] 6.1 Write unit tests for presigned URL generation
- [ ] 6.2 Write unit tests for S3 operations (mocked)
- [ ] 6.3 Write integration tests for image endpoints
- [ ] 6.4 Update API documentation
- [ ] 6.5 Deploy API to Fly.io

## Phase 7: Web - Gallery Component

- [ ] 7.1 Install GLightbox dependency
- [ ] 7.2 Create `ImageGallery.svelte` component
- [ ] 7.3 Create `ImageCard.svelte` for individual image display
- [ ] 7.4 Implement category filter UI
- [ ] 7.5 Implement hero image display (larger, prominent)
- [ ] 7.6 Integrate GLightbox for full-size viewing
- [ ] 7.7 Add no-image placeholder for species without images
- [ ] 7.8 Integrate gallery into `SpeciesDetail.svelte`

## Phase 8: Web - Admin Upload UI

- [ ] 8.1 Create `ImageUpload.svelte` component (file picker, presigned URL upload)
- [ ] 8.2 Create `ImageMetadataForm.svelte` (attribution fields)
- [ ] 8.3 Create `CategorySelect.svelte` (multi-select typeahead)
- [ ] 8.4 Implement upload flow: get presigned URL → upload to S3 → poll for status
- [ ] 8.5 Add upload progress indicator and processing status display
- [ ] 8.6 Add iNat API client in `web/src/lib/inatClient.js`
- [ ] 8.7 Create `INatImport.svelte` component (URL input, API call, metadata preview)
- [ ] 8.8 Implement multi-photo selection for iNat observations (batch select)
- [ ] 8.9 Implement iNat import flow (paste URL → client fetches iNat → preview → select photos → confirm → send to Oak API)
- [ ] 8.10 Add upload button to species detail page (admin-only)
- [ ] 8.11 Add image management UI (edit metadata, delete, set hero)
- [ ] 8.12 Add processing delay notice in UI ("Processing may take 10-15 seconds")

## Phase 9: Web - Testing & Polish

- [ ] 9.1 Write component tests for gallery
- [ ] 9.2 Write component tests for upload flow
- [ ] 9.3 Test mobile gallery experience
- [ ] 9.4 Test lightbox on mobile (touch gestures)
- [ ] 9.5 Verify admin-only access controls
- [ ] 9.6 Add alt text to images (use caption or "Photo of {species} {category}")
- [ ] 9.7 Ensure gallery keyboard navigation (arrow keys, tab)
- [ ] 9.8 Add native lazy loading to thumbnails (`loading="lazy"`)
- [ ] 9.9 Deploy web app

## Phase 10: Documentation

- [ ] 10.1 Update CLAUDE.md with image system overview
- [ ] 10.2 Document S3/CloudFront/Lambda setup for future reference
- [ ] 10.3 Document image upload workflow for admin use
