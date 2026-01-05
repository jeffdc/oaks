# api-server Delta: Add Species Images

## ADDED Requirements

### Requirement: Image Storage Configuration

The API SHALL support AWS S3 for image storage with CloudFront CDN for delivery.

#### Scenario: S3 credentials configured

- **WHEN** server starts with `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables
- **THEN** server initializes S3 client for image operations
- **AND** server can upload and delete objects from configured bucket

#### Scenario: S3 credentials missing

- **WHEN** server starts without AWS credentials
- **THEN** server logs warning that image features are disabled
- **AND** image upload endpoints return 503 Service Unavailable

#### Scenario: CloudFront URL generation

- **WHEN** image is stored successfully
- **THEN** server generates CloudFront URLs for all sizes
- **AND** URLs follow pattern `https://{cdn-domain}/{size}/{image-id}.{ext}`

### Requirement: Image Upload via Presigned URL

The API SHALL provide an endpoint to initiate image uploads via presigned S3 URLs.

#### Scenario: Request upload URL

- **WHEN** client sends `POST /api/v1/images/upload` with JSON body
- **AND** body includes `species_id`, `categories` (JSON array), `creator`, `license`, `content_type`
- **AND** `content_type` is one of: image/jpeg, image/png, image/webp
- **AND** user is authenticated
- **THEN** server creates image record with status "pending"
- **AND** server derives file extension from content_type (jpeg→.jpg, png→.png, webp→.webp)
- **AND** server generates presigned S3 upload URL for originals/{id}.{ext}
- **AND** presigned URL includes Content-Type condition matching provided content_type
- **AND** server returns 201 Created with image ID, presigned URL, and status

#### Scenario: Upload response format

- **WHEN** upload request succeeds
- **THEN** response contains:
  - `id`: UUID for the image
  - `upload_url`: Presigned S3 URL (valid for 1 hour, includes Content-Length condition max 20MB)
  - `status`: "pending"
  - `expires_at`: Presigned URL expiration timestamp

#### Scenario: Upload with optional metadata

- **WHEN** client sends `POST /api/v1/images/upload` with optional fields
- **AND** body includes `source_url`, `date_taken`, `location_name`, `latitude`, `longitude`, `caption`, `permission_notes`
- **THEN** all optional fields are stored in image record

#### Scenario: Upload sets hero if first image

- **WHEN** client uploads image for species with no existing images
- **THEN** uploaded image is automatically set as hero (`is_hero = true`)

#### Scenario: Upload without authentication

- **WHEN** client sends `POST /api/v1/images/upload` without Authorization header
- **THEN** server returns 401 Unauthorized

#### Scenario: Upload with missing required fields

- **WHEN** client sends upload missing `species_id`, `categories`, `creator`, `license`, or `content_type`
- **THEN** server returns 400 Bad Request
- **AND** response identifies missing fields

#### Scenario: Upload for non-existent species

- **WHEN** client sends upload with `species_id` that does not exist
- **THEN** server returns 404 Not Found

### Requirement: Image Status Polling

The API SHALL support polling for image processing status.

#### Scenario: Poll pending image

- **WHEN** client sends `GET /api/v1/images/{id}`
- **AND** image exists with status "pending"
- **THEN** server returns 200 OK
- **AND** response includes `status: "pending"`

#### Scenario: Poll processing image

- **WHEN** client sends `GET /api/v1/images/{id}`
- **AND** image exists with status "processing"
- **THEN** server returns 200 OK
- **AND** response includes `status: "processing"`

#### Scenario: Poll complete image

- **WHEN** client sends `GET /api/v1/images/{id}`
- **AND** image exists with status "complete"
- **THEN** server returns 200 OK
- **AND** response includes `status: "complete"`
- **AND** response includes CDN URLs for all sizes

#### Scenario: Poll failed image

- **WHEN** client sends `GET /api/v1/images/{id}`
- **AND** image exists with status starting with "failed"
- **THEN** server returns 200 OK
- **AND** response includes status (e.g., "failed:unsupported_format", "failed:corrupt_file", "failed:processing_error")

### Requirement: Image Status Update

The API SHALL provide an endpoint for Lambda to update image status.

#### Scenario: Lambda updates status to processing

- **WHEN** Lambda sends `PUT /api/v1/images/{id}/status`
- **AND** body includes `status: "processing"`
- **THEN** server updates image status
- **AND** server returns 200 OK

#### Scenario: Lambda updates status to complete

- **WHEN** Lambda sends `PUT /api/v1/images/{id}/status`
- **AND** body includes `status: "complete"` and S3 keys for processed images
- **THEN** server updates image status and S3 keys
- **AND** server returns 200 OK

#### Scenario: Lambda updates status to failed

- **WHEN** Lambda sends `PUT /api/v1/images/{id}/status`
- **AND** body includes status with failure reason (e.g., "failed:unsupported_format")
- **THEN** server updates image status
- **AND** server returns 200 OK

#### Scenario: Status update authentication

- **WHEN** status update request is sent
- **THEN** request must include valid API key via `Authorization: Bearer` header
- **AND** Lambda uses a separate API key (not shared with web client)
- **AND** Lambda API key is stored in Lambda environment variable `OAK_API_KEY`

### Requirement: Image Import from URL

The API SHALL provide an endpoint to import images from external URLs with client-provided metadata. The API invokes Lambda directly (Lambda downloads and processes the image).

#### Scenario: Import image from URL

- **WHEN** client sends `POST /api/v1/images/import-url`
- **AND** body includes `image_url`, `species_id`, `categories`, `creator`, `license`
- **AND** user is authenticated
- **THEN** server creates image record with status "pending"
- **AND** server invokes Lambda directly via AWS SDK with image URL and image ID
- **AND** server returns 201 Created with image ID and status "pending"
- **AND** client polls `GET /api/v1/images/{id}` until status is "complete"
- **AND** Lambda downloads from URL, processes, uploads to S3, updates status

#### Scenario: Import with optional metadata

- **WHEN** client sends `POST /api/v1/images/import-url` with optional fields
- **AND** body includes `source_url`, `date_taken`, `location_name`, `latitude`, `longitude`, `caption`
- **THEN** all optional fields are stored in image record

#### Scenario: Import sets hero if first image

- **WHEN** client imports image for species with no existing images
- **THEN** imported image is automatically set as hero (`is_hero = true`)

#### Scenario: Import without authentication

- **WHEN** client sends `POST /api/v1/images/import-url` without Authorization header
- **THEN** server returns 401 Unauthorized

#### Scenario: Import for non-existent species

- **WHEN** client sends import with `species_id` that does not exist
- **THEN** server returns 404 Not Found

#### Scenario: Import URL validation failures handled by Lambda

- **WHEN** Lambda fails to download from URL (404, timeout, invalid content type, oversized)
- **THEN** Lambda updates image status to failed with reason (e.g., "failed:download_timeout", "failed:invalid_content_type", "failed:file_too_large")
- **AND** client sees failure status when polling

### Requirement: List Species Images

The API SHALL provide an endpoint to list all images for a species.

#### Scenario: List images for species

- **WHEN** client sends `GET /api/v1/species/{name}/images`
- **AND** species exists
- **THEN** server returns 200 OK
- **AND** response contains array of image metadata
- **AND** hero image is first in array
- **AND** remaining images are ordered by category (habitat, growth_form, bark, leaf_shape, upper_leaf_vestiture, lower_leaf_vestiture, buds, twigs, twig_vestiture, acorns, flowers, fall_color)
- **AND** images with multiple categories are sorted by their first category in the defined order
- **AND** within a category, images are sorted by created_at ascending
- **AND** each image includes CDN URLs for all sizes

#### Scenario: List images with category filter

- **WHEN** client sends `GET /api/v1/species/{name}/images?category=bark`
- **THEN** response contains only images with "bark" in categories

#### Scenario: List images for species with none

- **WHEN** client sends `GET /api/v1/species/{name}/images`
- **AND** species has no images
- **THEN** server returns 200 OK
- **AND** response contains empty array

#### Scenario: List images for non-existent species

- **WHEN** client sends `GET /api/v1/species/{name}/images`
- **AND** species does not exist
- **THEN** server returns 404 Not Found

### Requirement: Get Image Metadata

The API SHALL provide an endpoint to get metadata for a single image.

#### Scenario: Get image by ID

- **WHEN** client sends `GET /api/v1/images/{id}`
- **AND** image exists
- **THEN** server returns 200 OK
- **AND** response contains full image metadata including CDN URLs

#### Scenario: Get non-existent image

- **WHEN** client sends `GET /api/v1/images/{id}`
- **AND** image does not exist
- **THEN** server returns 404 Not Found

### Requirement: Update Image Metadata

The API SHALL provide an endpoint to update image metadata.

#### Scenario: Update image categories

- **WHEN** client sends `PUT /api/v1/images/{id}` with `categories` field
- **AND** user is authenticated
- **THEN** server updates categories
- **AND** returns 200 OK with updated metadata

#### Scenario: Update image caption

- **WHEN** client sends `PUT /api/v1/images/{id}` with `caption` field
- **AND** user is authenticated
- **THEN** server updates caption
- **AND** returns 200 OK

#### Scenario: Update without authentication

- **WHEN** client sends `PUT /api/v1/images/{id}` without Authorization header
- **THEN** server returns 401 Unauthorized

#### Scenario: Update non-existent image

- **WHEN** client sends `PUT /api/v1/images/{id}` for non-existent image
- **THEN** server returns 404 Not Found

### Requirement: Delete Image

The API SHALL provide an endpoint to delete images.

#### Scenario: Delete image

- **WHEN** client sends `DELETE /api/v1/images/{id}`
- **AND** user is authenticated
- **AND** image exists
- **THEN** server deletes image record from database
- **AND** server deletes all image files from S3 (original, thumb, medium, large)
- **AND** server returns 204 No Content

#### Scenario: Delete hero image promotes next

- **WHEN** client deletes hero image
- **AND** species has other images
- **THEN** oldest remaining image becomes new hero

#### Scenario: Delete without authentication

- **WHEN** client sends `DELETE /api/v1/images/{id}` without Authorization header
- **THEN** server returns 401 Unauthorized

#### Scenario: Delete non-existent image

- **WHEN** client sends `DELETE /api/v1/images/{id}` for non-existent image
- **THEN** server returns 404 Not Found

### Requirement: Set Hero Image

The API SHALL provide an endpoint to designate an image as the hero for its species.

#### Scenario: Set hero image

- **WHEN** client sends `POST /api/v1/images/{id}/hero`
- **AND** user is authenticated
- **AND** image exists
- **THEN** server sets `is_hero = true` for this image
- **AND** server sets `is_hero = false` for all other images of same species
- **AND** server returns 200 OK

#### Scenario: Set hero without authentication

- **WHEN** client sends `POST /api/v1/images/{id}/hero` without Authorization header
- **THEN** server returns 401 Unauthorized

#### Scenario: Set hero for non-existent image

- **WHEN** client sends `POST /api/v1/images/{id}/hero` for non-existent image
- **THEN** server returns 404 Not Found

### Requirement: Image Processing (Lambda)

Image processing SHALL be handled by AWS Lambda via two trigger paths: S3 event (direct uploads) or direct invoke (URL imports).

#### Configuration: Lambda Runtime

- Runtime: Node.js 20.x
- Architecture: ARM64 (cost efficiency)
- Memory: 512MB
- Timeout: 60 seconds
- VPC: None (uses default internet access)
- Environment variables:
  - `OAK_API_URL`: API endpoint (e.g., "https://api.oakcompendium.com")
  - `OAK_API_KEY`: Separate API key for Lambda (not shared with web client)

#### Configuration: Lambda Layer

- Library: Sharp (wraps libvips for image processing)
- Layer: Pre-built ARM64 Sharp layer (cbschuld/sharp-aws-lambda-layer or equivalent)
- Version: Pin specific layer ARN for reproducibility

#### Scenario: Lambda detects trigger path

- **WHEN** Lambda is invoked
- **AND** event contains `Records[0].s3` property
- **THEN** Lambda handles as S3 trigger (Path A: direct upload)

- **WHEN** Lambda is invoked
- **AND** event contains `imageUrl` and `imageId` properties
- **THEN** Lambda handles as direct invoke (Path B: URL import)

#### Scenario: Lambda extracts image ID from S3 key (Path A)

- **WHEN** Lambda receives S3 event for object key `originals/{id}.{ext}`
- **THEN** Lambda extracts image ID from the key path (e.g., `originals/abc123.jpg` → `abc123`)

#### Scenario: Lambda downloads from URL (Path B)

- **WHEN** Lambda receives direct invoke with `imageUrl`
- **THEN** Lambda sends HEAD request to check Content-Type and Content-Length
- **AND** Lambda rejects if Content-Type is not image/jpeg, image/png, or image/webp (status: "failed:invalid_content_type")
- **AND** Lambda rejects if Content-Length > 20MB (status: "failed:file_too_large")
- **AND** Lambda downloads with 30 second timeout (status: "failed:download_timeout" on timeout)
- **AND** Lambda uploads original to S3 `originals/{id}.{ext}`

#### Scenario: Lambda detects and corrects format mismatch

- **WHEN** Lambda processes image
- **THEN** Lambda uses Sharp to detect actual format from magic bytes
- **AND** if detected format differs from file extension, Lambda updates S3 key with correct extension

#### Scenario: Lambda processes uploaded image

- **WHEN** original image is in S3 `originals/` prefix
- **THEN** Lambda uses Sharp to generate thumbnail (200px longest edge, WebP)
- **AND** Lambda uses Sharp to generate medium (800px longest edge, WebP)
- **AND** Lambda uses Sharp to generate large (1600px longest edge, WebP)
- **AND** Lambda preserves original at full resolution in original format
- **AND** Lambda uploads processed images to S3
- **AND** Lambda calls API to update status to "complete"

#### Scenario: Aspect ratio preserved

- **WHEN** image is resized by Lambda
- **THEN** original aspect ratio is maintained
- **AND** longest edge matches target size

#### Scenario: Lambda retries API callback on failure

- **WHEN** Lambda attempts to call API to update status
- **AND** API request fails (network error, 5xx response)
- **THEN** Lambda retries up to 3 times with exponential backoff
- **AND** if all retries fail, Lambda logs error and exits (image remains in previous status)

#### Scenario: Processing failure with cleanup

- **WHEN** Lambda fails to process image
- **THEN** Lambda deletes any partial uploads (thumb, medium, large) from S3
- **AND** Lambda calls API to update status with failure reason (e.g., "failed:unsupported_format", "failed:corrupt_file")

### Requirement: Image Categories Validation

The API SHALL validate image categories against a fixed list.

#### Scenario: Valid categories accepted

- **WHEN** client provides categories from allowed list
- **AND** list includes: habitat, growth_form, bark, leaf_shape, upper_leaf_vestiture, lower_leaf_vestiture, buds, twigs, twig_vestiture, acorns, flowers, fall_color
- **THEN** categories are accepted

#### Scenario: Invalid category rejected

- **WHEN** client provides category not in allowed list
- **THEN** server returns 400 Bad Request
- **AND** response indicates invalid category

#### Scenario: Empty categories rejected

- **WHEN** client provides empty categories array
- **THEN** server returns 400 Bad Request
- **AND** response indicates at least one category required

### Requirement: License Validation

The API SHALL validate license values.

#### Scenario: Valid licenses accepted

- **WHEN** client provides license value
- **AND** value is one of: cc0, cc-by, cc-by-sa, cc-by-nc, cc-by-nc-sa, cc-by-nd, cc-by-nc-nd, arr
- **THEN** license is accepted

#### Scenario: Invalid license rejected

- **WHEN** client provides invalid license value
- **THEN** server returns 400 Bad Request
- **AND** response indicates invalid license

### Requirement: Species Deletion Cascades to Images

The API SHALL delete all images when a species is deleted.

#### Scenario: Delete species with images

- **WHEN** client sends `DELETE /api/v1/species/{name}`
- **AND** species has images
- **THEN** server deletes all image files from S3 (all sizes for each image)
- **AND** server deletes all image records from database
- **AND** server deletes species record
- **AND** server returns 204 No Content

#### Scenario: Delete species with no images

- **WHEN** client sends `DELETE /api/v1/species/{name}`
- **AND** species has no images
- **THEN** species is deleted normally

### Requirement: Image Metadata in Species Full Endpoint

The API SHALL include image data in the full species endpoint.

#### Scenario: Full species includes images

- **WHEN** client sends `GET /api/v1/species/{name}/full`
- **AND** species has images
- **THEN** response includes `images` array
- **AND** hero image is first
- **AND** each image includes CDN URLs

#### Scenario: Full species with no images

- **WHEN** client sends `GET /api/v1/species/{name}/full`
- **AND** species has no images
- **THEN** response includes empty `images` array
