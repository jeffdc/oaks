# Oak Compendium

A comprehensive database and query tool for *Quercus* (oak) species and
their hybrids.

**Live site:** [oakcompendium.org](https://oakcompendium.org/)

## Features

- Complete iNaturalist *Quercus* taxonomy and species list
- Multi-source descriptive data (iNaturalist, Oaks of the World, personal
  observations) with per-source attribution
- Taxonomy browser by subgenus, section, subsection, and complex
- Hybrid lookup and parent-formula display
- JSON API with OpenAPI/Swagger docs at `/api/swagger`

## Tech Stack

- **Framework**: Phoenix 1.8+ with LiveView
- **Database**: SQLite via Ecto + ecto_sqlite3
- **HTTP Server**: Bandit
- **Styling**: Tailwind v4
- **Deployment**: Fly.io with Litestream (S3 replication)

## Quick Start

Requirements: Elixir 1.17+ / OTP 27+, SQLite 3, Node.js (for assets).

```bash
# Install deps, set up DB, build assets
mix setup

# Start the dev server at http://localhost:4000
mix phx.server
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for full development setup and
contribution guidelines, and [CLAUDE.md](CLAUDE.md) for the project guide
(architecture, workflows, conventions).

## Project Layout

| Directory | What |
|---|---|
| `lib/oaks/` | Business logic contexts |
| `lib/oaks_web/` | Web layer (LiveViews, controllers, components) |
| `config/` | Phoenix configuration |
| `assets/` | JS, CSS, Tailwind |
| `priv/repo/` | Migrations, `structure.sql`, seeds |
| `test/` | Elixir tests |
| `scrapers/` | Python scripts for ingesting external data (local dev only) |
| `cli/` | Legacy Go CLI (frozen reference) |
| `ios/` | iOS app source |

## Data Sources

| Source | ID | Purpose |
|---|---|---|
| iNaturalist | 1 | Authoritative taxonomy and species list |
| Oaks of the World | 2 | Morphological descriptions, distribution, local names |
| Oak Compendium | 3 | Personal observations (preferred for display) |

Every data point is linked to its source via the `species_sources` table.
Source 3 (personal observations) takes precedence in the UI when present.

## License

Dual-licensed:

- **Source code**: MIT License — see [LICENSE](LICENSE)
- **Data files**: All Rights Reserved — see [DATA_LICENSE](DATA_LICENSE)

The data files (`oaks.db`, `data/`, scraped JSON) are proprietary and not
covered by the MIT License. The data incorporates information from
multiple sources; see the application for individual source attributions.

## Acknowledgments

Thanks to the maintainers of [iNaturalist](https://www.inaturalist.org/),
[Oaks of the World](https://oaksoftheworld.fr), and the broader oak
research community for the data this project builds on.
