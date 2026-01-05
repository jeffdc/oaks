# web-images Specification

## Purpose

The web-images capability provides the user interface for viewing and managing species images in the Oak Compendium web application.

## ADDED Requirements

### Requirement: Species Image Gallery

The web app SHALL display an image gallery on species detail pages.

#### Scenario: Display hero image

- **WHEN** user views species detail page
- **AND** species has images
- **THEN** hero image is displayed prominently
- **AND** hero image uses medium size for initial display

#### Scenario: Display gallery thumbnails

- **WHEN** user views species detail page
- **AND** species has multiple images
- **THEN** thumbnails are displayed below or beside hero image
- **AND** thumbnails use thumb size

#### Scenario: No images placeholder

- **WHEN** user views species detail page
- **AND** species has no images
- **THEN** a placeholder is displayed indicating no images available

#### Scenario: Gallery is mobile-friendly

- **WHEN** user views gallery on mobile device
- **THEN** gallery adapts to screen size
- **AND** thumbnails are appropriately sized for touch

### Requirement: Image Lightbox

The web app SHALL provide a full-size image viewer using GLightbox.

#### Scenario: Open lightbox

- **WHEN** user clicks on hero image or thumbnail
- **THEN** lightbox opens showing large size image

#### Scenario: Navigate images in lightbox

- **WHEN** lightbox is open
- **AND** species has multiple images
- **THEN** user can navigate between images using arrows or swipe

#### Scenario: Keyboard navigation

- **WHEN** lightbox is open
- **THEN** user can press arrow keys to navigate
- **AND** user can press Escape to close

#### Scenario: Touch gestures

- **WHEN** lightbox is open on mobile
- **THEN** user can swipe to navigate between images
- **AND** user can pinch to zoom

#### Scenario: View original resolution

- **WHEN** user is viewing image in lightbox
- **THEN** user can access original resolution image (link or zoom)

### Requirement: Gallery Category Filter

The web app SHALL allow filtering gallery images by category.

#### Scenario: Display category filter

- **WHEN** user views gallery with images in multiple categories
- **THEN** category filter UI is displayed
- **AND** shows only categories present in current species images

#### Scenario: Filter by single category

- **WHEN** user selects a category (e.g., "bark")
- **THEN** gallery shows only images with that category
- **AND** filter state is visually indicated

#### Scenario: Clear filter

- **WHEN** user clears category filter
- **THEN** gallery shows all images

### Requirement: Image Attribution Display

The web app SHALL display attribution for images.

#### Scenario: Minimal attribution shown

- **WHEN** user views image in gallery or lightbox
- **THEN** creator name and license are visible
- **AND** format is concise (e.g., "Photo: John Smith, CC-BY")

#### Scenario: Full attribution on demand

- **WHEN** user clicks attribution or info icon
- **THEN** full attribution is displayed
- **AND** includes: creator, license, source URL, date, location, caption

#### Scenario: Source link

- **WHEN** image has source URL (e.g., iNat observation)
- **THEN** link to source is available in full attribution

### Requirement: Admin Image Upload

The web app SHALL provide image upload functionality for admin users.

#### Scenario: Upload button visible to admin

- **WHEN** admin user views species detail page
- **THEN** "Add Image" button is visible
- **AND** button is not visible to non-admin users

#### Scenario: Direct file upload

- **WHEN** admin clicks "Add Image"
- **THEN** upload dialog opens
- **AND** admin can select image file from device
- **AND** admin must enter: categories (multi-select), creator, license
- **AND** admin can optionally enter: date, location, caption, permission notes

#### Scenario: Upload progress indicator

- **WHEN** upload is in progress
- **THEN** progress indicator is displayed
- **AND** user cannot submit another upload until complete

#### Scenario: Upload success

- **WHEN** upload completes successfully
- **THEN** new image appears in gallery
- **AND** success message is displayed

#### Scenario: Processing delay notice

- **WHEN** upload or import is initiated
- **THEN** UI displays notice "Processing may take 10-15 seconds"
- **AND** shows processing status while polling

#### Scenario: Upload error

- **WHEN** upload fails
- **THEN** error message is displayed
- **AND** user can retry

### Requirement: iNaturalist Import

The web app SHALL provide iNaturalist image import for admin users, with client-side iNat API integration.

#### Scenario: iNat import option

- **WHEN** admin opens upload dialog
- **THEN** "Import from iNaturalist" option is available

#### Scenario: Paste iNat URL

- **WHEN** admin selects iNat import
- **THEN** URL input field is displayed
- **AND** admin can paste iNat observation URL

#### Scenario: Metadata preview via client-side API call

- **WHEN** admin pastes valid iNat URL
- **THEN** web app calls iNat API directly from browser
- **AND** displays preview: thumbnail, photographer, license, date, location
- **AND** admin can review before confirming

#### Scenario: Multi-photo observations with batch select

- **WHEN** iNat observation has multiple photos
- **THEN** all photos are shown in preview with checkboxes
- **AND** admin can select multiple photos to import (batch select)
- **AND** selected categories apply to all selected photos

#### Scenario: Confirm import

- **WHEN** admin confirms import
- **AND** selects categories
- **THEN** web app sends image URL and metadata to Oak API for each selected photo
- **AND** Lambda downloads and processes each image
- **AND** images appear in gallery as processing completes

#### Scenario: Invalid iNat URL

- **WHEN** admin enters invalid URL
- **THEN** error message indicates URL is not valid

#### Scenario: iNat API error

- **WHEN** iNat API is unreachable or returns error
- **THEN** error message indicates iNaturalist could not be reached

### Requirement: Admin Image Management

The web app SHALL allow admin to manage existing images.

#### Scenario: Edit image metadata

- **WHEN** admin views image in gallery
- **THEN** edit option is available
- **AND** admin can update: categories, caption

#### Scenario: Delete image

- **WHEN** admin views image in gallery
- **THEN** delete option is available
- **AND** confirmation is required before deletion

#### Scenario: Set as hero

- **WHEN** admin views non-hero image
- **THEN** "Set as Hero" option is available
- **AND** selecting it makes image the hero

### Requirement: Category Multi-Select

The web app SHALL provide a multi-select typeahead for category selection.

#### Scenario: Category selection during upload

- **WHEN** admin is entering image metadata
- **THEN** category field is a multi-select typeahead
- **AND** shows available categories as user types
- **AND** allows selecting multiple categories

#### Scenario: At least one category required

- **WHEN** admin attempts to upload without selecting categories
- **THEN** validation error indicates categories required

#### Scenario: Available categories

- **WHEN** category selector is active
- **THEN** available options are: habitat, growth_form, bark, leaf_shape, upper_leaf_vestiture, lower_leaf_vestiture, buds, twigs, twig_vestiture, acorns, flowers, fall_color

### Requirement: Accessibility

The web app SHALL meet basic accessibility standards for the image gallery.

#### Scenario: Image alt text

- **WHEN** image is displayed in gallery or lightbox
- **THEN** image has alt text
- **AND** alt text uses caption if available, otherwise "Photo of {species} {category}"

#### Scenario: Keyboard navigation in gallery

- **WHEN** user navigates gallery with keyboard
- **THEN** thumbnails are focusable with Tab key
- **AND** Enter key opens focused image in lightbox

#### Scenario: Native lazy loading

- **WHEN** gallery displays thumbnails
- **THEN** thumbnail images use `loading="lazy"` attribute
- **AND** only visible thumbnails load initially
