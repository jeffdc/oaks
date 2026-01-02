# Change: Add WASM Species Linker (Client-Side Alternative)

## Status

**ALTERNATIVE PROPOSAL** - This is an alternative to `add-species-name-parser`. Choose one approach, not both.

| Aspect | add-species-name-parser | add-wasm-species-linker (this) |
|--------|-------------------------|--------------------------------|
| Language | Go | Rust compiled to WASM |
| Linking | Server-side at save time | Client-side at render time |
| Stored content | Contains embedded links | Raw text (no links) |
| Link freshness | Can become stale | Always current |
| Code reuse | Go API only | Browser + iOS + Go (via wazero) |
| Build complexity | Go only | Go + Rust + wasm-pack |

## Why

The `add-content-expansion` proposal requires automatic linking of species mentions in markdown content. The original `add-species-name-parser` proposal uses a Go parser running server-side at save time.

This alternative uses a Rust parser compiled to WebAssembly, enabling:

1. **Client-side linking**: Links resolved at render time, not save time. Stored content stays clean.
2. **Cross-platform reuse**: Same WASM artifact works in browser, iOS app, and Go API (if needed).
3. **Better parsing ergonomics**: Rust's `nom` library provides cleaner parser combinator patterns than Go regex.
4. **Offline capability**: Browser already has species list in IndexedDB; WASM parser runs locally.

## What Changes

- **NEW** `rust-parser/` crate: Rust library for species name parsing, compiled to WASM
- **NEW** `species-linker` capability: Client-side species mention detection and linking
- **MODIFIED** Web app: Loads WASM parser, links species at render time
- **MODIFIED** Content storage: API stores raw markdown (no embedded links)
- **FUTURE** iOS app: Can use same WASM via JavaScriptCore or Wasmer

## Impact

- **Affected specs**: None existing (new capability)
- **Affected code**:
  - `rust-parser/` (new Rust crate)
  - `web/src/lib/speciesLinker.js` (WASM loader + resolver)
  - `web/src/components/` (render with linking)
- **Dependencies**: `add-content-expansion` would use this instead of `add-species-name-parser`
- **Build changes**: CI needs Rust toolchain and `wasm-pack`

## Trade-offs Accepted

### Giving Up
- Pre-embedded links in stored content
- Trivial server-side backlinks query (can't grep stored content for links)

### Getting
- Cleaner stored data (raw markdown, no embedded links that can break)
- Always-fresh links (species renames don't break existing content)
- Cross-platform code reuse (browser, iOS, potentially Go)
- Better parsing ergonomics (Rust > Go for this problem)
- Full offline capability

## Backlinks Mitigation

Server-side backlinks ("which articles mention Q. alba?") require different approach:

1. **Option A**: Maintain separate `mentions` table updated on save (parse but don't embed)
2. **Option B**: Parse all content on demand (acceptable for small corpus)
3. **Option C**: Client-side search feature (parse and filter in browser)

Recommended: Option A for structured backlinks API, with Option C as fallback.

## References

- [WASM Browser Support](https://caniuse.com/wasm) - 97% global support
- [wasm-pack](https://rustwasm.github.io/wasm-pack/) - Rust to WASM toolchain
- [nom parser combinators](https://github.com/rust-bakery/nom) - Rust parsing library
- [wazero](https://wazero.io/) - Pure Go WASM runtime (if Go needs to call parser)
- [Wasmer Swift](https://github.com/aspect-apps/aspect-ration) - iOS WASM runtime option
