# cli-api-client Specification (Delta)

## ADDED Requirements

### Requirement: CLI API Client Configuration
The CLI SHALL support configuration for connecting to remote API servers via named profiles.

#### Scenario: Profile-based configuration
- **WHEN** `~/.oak/config.yaml` exists with named profiles
- **THEN** CLI uses URL and key from the active profile
- **AND** profiles contain `url` and `key` fields

#### Scenario: Default profile selection
- **WHEN** no profile is explicitly specified
- **AND** config file has `default_profile` set
- **THEN** CLI uses the default profile

#### Scenario: Profile selection via flag
- **WHEN** user runs command with `--profile staging`
- **THEN** CLI uses the `staging` profile from config

#### Scenario: Profile selection via environment
- **WHEN** `OAK_PROFILE` environment variable is set to `prod`
- **AND** no `--profile` flag is provided
- **THEN** CLI uses the `prod` profile from config

#### Scenario: Legacy environment variables override profiles
- **WHEN** `OAK_API_URL` environment variable is set
- **THEN** CLI uses that URL regardless of profile settings
- **AND** `OAK_API_KEY` provides authentication

#### Scenario: No configuration
- **WHEN** no API configuration exists
- **AND** user attempts remote operation with `--remote` flag
- **THEN** CLI displays error with configuration instructions

### Requirement: Configuration Management
The CLI SHALL provide commands to view and manage API configuration.

#### Scenario: Show active configuration
- **WHEN** user runs `oak config show`
- **THEN** CLI displays active profile name
- **AND** displays API URL (key is masked)
- **AND** displays profile resolution source (flag/env/config)

#### Scenario: List profiles
- **WHEN** user runs `oak config list`
- **THEN** CLI displays all configured profile names
- **AND** marks the default profile

### Requirement: Local vs Remote Mode
The CLI SHALL support both local database access and remote API operations.

#### Scenario: Default to local mode
- **WHEN** no API profile is configured or no default_profile is set
- **AND** user runs a supported command without mode flags
- **THEN** CLI operates against the local database

#### Scenario: Use configured default profile
- **WHEN** config file has `default_profile` set
- **AND** user runs a supported command without mode flags
- **THEN** CLI operates against the remote API using default profile

#### Scenario: Force local mode
- **WHEN** user runs command with `--local` flag
- **THEN** CLI operates against local database
- **AND** ignores API configuration

#### Scenario: Force remote mode
- **WHEN** user runs command with `--remote` flag
- **AND** API is configured
- **THEN** CLI operates against the remote API

#### Scenario: Force remote without configuration
- **WHEN** user runs command with `--remote` flag
- **AND** API is not configured
- **THEN** CLI displays error with configuration instructions

### Requirement: Destructive Operation Safety
The CLI SHALL display the active profile for destructive operations to prevent accidental production changes.

#### Scenario: Delete confirmation shows profile
- **WHEN** user runs `oak delete alba` in remote mode
- **THEN** CLI displays "Delete alba from [profile-name]? (y/N)"
- **AND** profile name is shown in brackets

#### Scenario: Update confirmation shows profile
- **WHEN** user runs `oak edit alba` and saves changes
- **THEN** CLI displays "Update alba on [profile-name]? (y/N)"

#### Scenario: Create shows profile
- **WHEN** user runs `oak new` and saves
- **THEN** CLI displays "Create on [profile-name]? (y/N)"

### Requirement: API Version Compatibility
The CLI SHALL verify compatibility with the connected API server.

#### Scenario: Compatible versions
- **WHEN** CLI connects to API server
- **AND** CLI version meets API's minimum client requirement
- **THEN** operations proceed normally

#### Scenario: CLI too old
- **WHEN** CLI version is older than API's `min_client` version
- **THEN** CLI displays error with upgrade instructions
- **AND** operation is blocked

#### Scenario: CLI newer than API
- **WHEN** CLI version is newer than API version
- **THEN** CLI displays warning about potential reduced functionality
- **AND** operation proceeds

#### Scenario: Version check failure
- **WHEN** version check request fails
- **THEN** CLI displays warning
- **AND** operation proceeds anyway

#### Scenario: Skip version check
- **WHEN** user runs command with `--skip-version-check`
- **THEN** CLI skips compatibility verification

#### Scenario: Display versions
- **WHEN** user runs `oak version`
- **AND** API is configured
- **THEN** CLI displays both CLI version and connected API version

### Requirement: Remote Species Operations
The CLI SHALL support species CRUD operations via the API.

#### Scenario: Find species remotely
- **WHEN** user runs `oak find <query>` in remote mode
- **THEN** CLI queries `GET /api/v1/species/search?q=<query>`
- **AND** displays matching species

#### Scenario: View species remotely
- **WHEN** user runs `oak show <name>` in remote mode
- **THEN** CLI queries `GET /api/v1/species/<name>`
- **AND** displays species details

#### Scenario: Create species remotely
- **WHEN** user runs `oak new` in remote mode
- **THEN** CLI opens editor for new species entry
- **AND** POSTs to `/api/v1/species` on save

#### Scenario: Edit species remotely
- **WHEN** user runs `oak edit <name>` in remote mode
- **THEN** CLI fetches species via `GET /api/v1/species/<name>`
- **AND** opens editor with species data
- **AND** PUTs to `/api/v1/species/<name>` on save

#### Scenario: Delete species remotely
- **WHEN** user runs `oak delete <name>` in remote mode
- **THEN** CLI prompts for confirmation with profile name
- **AND** sends `DELETE /api/v1/species/<name>`

### Requirement: Remote Taxa Operations
The CLI SHALL support taxa operations via the API.

#### Scenario: List taxa remotely
- **WHEN** user runs `oak taxa list` in remote mode
- **THEN** CLI queries `GET /api/v1/taxa`
- **AND** displays taxonomy hierarchy

#### Scenario: Create taxon remotely
- **WHEN** user runs `oak taxa new` in remote mode
- **THEN** CLI POSTs to `/api/v1/taxa`

### Requirement: Remote Source Operations
The CLI SHALL support source operations via the API.

#### Scenario: List sources remotely
- **WHEN** user runs `oak source list` in remote mode
- **THEN** CLI queries `GET /api/v1/sources`
- **AND** displays registered sources

#### Scenario: Create source remotely
- **WHEN** user runs `oak source new` in remote mode
- **THEN** CLI POSTs to `/api/v1/sources`

### Requirement: API Error Handling
The CLI SHALL handle API errors gracefully.

#### Scenario: Network error
- **WHEN** API server is unreachable
- **THEN** CLI displays connection error with URL and profile name
- **AND** suggests checking network or server status

#### Scenario: Authentication failure
- **WHEN** API returns 401 Unauthorized
- **THEN** CLI displays "Invalid API key for profile [name]"
- **AND** suggests checking configuration

#### Scenario: Not found error
- **WHEN** API returns 404 Not Found
- **THEN** CLI displays "Resource not found" message

#### Scenario: Rate limit exceeded
- **WHEN** API returns 429 Too Many Requests
- **THEN** CLI displays rate limit message
- **AND** shows retry-after duration if available

#### Scenario: Server error
- **WHEN** API returns 5xx error
- **THEN** CLI displays server error message
- **AND** suggests retrying later

### Requirement: Export from API
The CLI SHALL support exporting data from the remote API.

#### Scenario: Export from API
- **WHEN** user runs `oak export output.json --from-api`
- **THEN** CLI queries `GET /api/v1/export` using active profile
- **AND** saves response to specified file

#### Scenario: Export locally by default
- **WHEN** user runs `oak export output.json` without `--from-api`
- **THEN** CLI exports from local database
- **AND** ignores API configuration
