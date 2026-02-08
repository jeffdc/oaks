# Oak Notes iOS App

Native iOS app for field-by-field species dictation, enabling efficient data entry from physical books.

## Tech Stack
- SwiftUI, iOS 17+
- Speech framework for dictation
- iCloud export via UIDocumentPicker

## Current Status
Core dictation and editing implemented. Remaining: iCloud/markdown export, polish, TestFlight.

## Core Features (MVP)
1. Species list view (from local storage or manual entry)
2. Species edit view with field buttons
3. Tap field → dictation modal → save text
4. Export to iCloud as markdown

## Out of Scope for MVP
- Species lookup/autocomplete
- Photo attachment
- OCR
- Offline species database
- Sync back from CLI (one-way flow)

## Remaining Work

### iCloud Export
- Implement MarkdownService matching Bear format
- CloudExportService with UIDocumentPicker
- Export confirmation and tracking

### Polish and TestFlight
- App icon
- Onboarding flow
- Error handling
- TestFlight build

### UX: Reduce taps to start dictation
Current flow requires too many taps:
1. Open note → 2. Tap field → 3. Tap small mic icon → 4. Enter dictation panel → 5. Press mic to start

Ideas:
- When no content, go directly to edit view with all fields empty
- Auto-start dictation when entering dictation panel
- Larger/more prominent dictation button
- Shake-to-dictate or other gesture

### Remove timestamp from notes list
Not needed on the list screen.

### Research: Taxonomy-based notes organization
Current flat list won't scale. Questions:
- What taxonomy hierarchy levels to expose? (subgenus/section/species)
- Search UX: filter by taxonomy vs full-text search vs both?
- Navigation: drill-down vs flat list with filters?
- How to handle hybrids in taxonomy view?
- Should mirror the website approach and use iOS-native patterns
