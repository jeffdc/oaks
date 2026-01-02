# Tasks: WASM Species Linker

## 1. Rust Parser Core

- [ ] 1.1 Create `rust-parser/` crate with Cargo.toml (wasm-bindgen, nom, serde)
- [ ] 1.2 Define types in `src/types.rs` (ParseResult, Infraspecific)
- [ ] 1.3 Implement genus parser (`Quercus` | `Q.`)
- [ ] 1.4 Implement hybrid marker parser (`×` | `x` | `X`)
- [ ] 1.5 Implement epithet parser (lowercase, allow hyphens)
- [ ] 1.6 Implement infraspecific rank parser (all ICN ranks from cli/docs/infraspecific-ranks.md)
- [ ] 1.7 Implement `f.` disambiguation (forma vs filius)
- [ ] 1.8 Implement author citation patterns (parenthetical, ex, in, et)
- [ ] 1.9 Compose full `parse_species` function
- [ ] 1.10 Write unit tests for each sub-parser
- [ ] 1.11 Write integration tests matching `add-species-name-parser` spec scenarios

## 2. Text Scanner

- [ ] 2.1 Implement skip region detection (code blocks, inline code)
- [ ] 2.2 Implement skip region detection (markdown links, image alt text)
- [ ] 2.3 Implement skip region detection (URLs)
- [ ] 2.4 Implement genus marker finder ("Quercus" and "Q." occurrences)
- [ ] 2.5 Compose `scan_species` function with skip logic
- [ ] 2.6 Write scanner tests for skip scenarios
- [ ] 2.7 Write scanner tests for multiple mentions

## 3. WASM Build

- [ ] 3.1 Configure wasm-bindgen exports in `src/lib.rs`
- [ ] 3.2 Add wasm-pack build configuration
- [ ] 3.3 Optimize for size (opt-level, LTO)
- [ ] 3.4 Verify WASM artifact <100KB gzipped
- [ ] 3.5 Generate TypeScript definitions
- [ ] 3.6 Add GitHub Actions workflow for Rust/WASM build
- [ ] 3.7 Configure artifact caching in CI

## 4. Web Integration

- [ ] 4.1 Create `web/src/lib/wasmLoader.js` for async WASM initialization
- [ ] 4.2 Create `web/src/lib/speciesLinker.js` with resolver logic
- [ ] 4.3 Integrate with Dexie species lookups
- [ ] 4.4 Add WASM to Vite build configuration
- [ ] 4.5 Lazy load WASM after initial render
- [ ] 4.6 Add to service worker cache
- [ ] 4.7 Write integration tests for linker

## 5. Markdown Rendering Integration

- [ ] 5.1 Create species linking markdown extension/plugin
- [ ] 5.2 Integrate with existing markdown renderer (marked)
- [ ] 5.3 Link species in taxa content display
- [ ] 5.4 Link species in article content display
- [ ] 5.5 Test rendering with various content patterns

## 6. Backlinks (Optional - Choose Implementation)

### Option A: Mentions Table (Recommended)

- [ ] 6A.1 Add `mentions` table migration
- [ ] 6A.2 Update API save handlers to parse and index mentions
- [ ] 6A.3 Add `GET /api/v1/species/{name}/backlinks` endpoint
- [ ] 6A.4 Display backlinks on species detail pages

### Option B: Parse on Demand

- [ ] 6B.1 Add endpoint to scan all content for species
- [ ] 6B.2 Cache results with reasonable TTL
- [ ] 6B.3 Display backlinks on species detail pages

## 7. Documentation

- [ ] 7.1 Document Rust build requirements in README
- [ ] 7.2 Document WASM loading pattern for contributors
- [ ] 7.3 Add species linking usage examples
- [ ] 7.4 Update CLAUDE.md with Rust crate information

## 8. iOS Preparation (Future)

- [ ] 8.1 Research JavaScriptCore WASM integration
- [ ] 8.2 Create Swift wrapper prototype
- [ ] 8.3 Document iOS integration path

## Dependencies

- Tasks 4.x depend on Tasks 3.x (WASM build)
- Tasks 5.x depend on Tasks 4.x (web integration)
- Tasks 6.x can proceed in parallel with 5.x
- Tasks 8.x are future work, not blocking
