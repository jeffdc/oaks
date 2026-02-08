# Elixir/Phoenix Coding Standards

These standards apply to Elixir/Phoenix projects. LLM agents and human contributors must follow these conventions.

## Tooling is Authoritative

The following tools define and enforce our coding standards:

| Tool | Command | Purpose |
|------|---------|---------|
| **mix format** | `mix format` | Code formatting (line length, spacing, indentation) |
| **Credo** | `mix credo --strict` | Code quality, consistency, readability |
| **Dialyzer** | `mix dialyzer` | Type checking via typespecs |

**Rules:**
- Run `mix format` before committing
- All code must pass `mix credo --strict` with no errors
- All code must pass `mix dialyzer` with no warnings
- Treat warnings as errors during compilation (`--warnings-as-errors`)

**Line length:** The formatter targets 98 characters (default). Credo allows up to 120 characters but flags longer lines as low-priority warnings. Aim for 98; occasional lines up to 120 are acceptable.

If a tool enforces a rule, that rule is not documented here. If you're unsure about formatting or style, run the tools and follow their output.

---

## Module Structure

Organize modules in this order:

```elixir
defmodule Oaks.Context.Entity do
  @moduledoc """
  Brief description of what this module does.
  """

  # 1. use/import/alias/require (in this order)
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Oaks.Repo
  alias Oaks.Context.{OtherEntity, AnotherEntity}

  # 2. Module attributes
  @primary_key {:id, :integer, autogenerate: false}
  @topic "entity"

  # 3. Schema (if applicable)
  schema "entities" do
    field :name, :string
    belongs_to :parent, Parent
  end

  # 4. Public functions with @doc and @spec
  @doc """
  Returns all entities.
  """
  @spec list_entities() :: [Entity.t()]
  def list_entities do
    Repo.all(Entity)
  end

  # 5. Private functions
  defp helper_function(arg) do
    # ...
  end
end
```

---

## Documentation

### Module Documentation

Public API modules (contexts, controllers, LiveViews) should have a `@moduledoc`:

```elixir
@moduledoc """
The Species context.

Provides functions for querying and managing species records,
including their relationships to sources, taxonomy, and hybrids.
"""
```

For internal/infrastructure modules (Application, Repo, generated code), use `@moduledoc false`.

For schema modules, briefly describe what the entity represents.

### Function Documentation

Public functions must have `@doc` and `@spec`:

```elixir
@doc """
Fetches a species by scientific name.

Returns `nil` if not found.
"""
@spec get_species_by_name(String.t()) :: Species.t() | nil
def get_species_by_name(name), do: Repo.get_by(Species, scientific_name: name)
```

Private functions do not need `@doc` or `@spec` unless complex.

### Typespecs

Use typespecs for:
- All public function arguments and return values
- Custom types that improve readability
- Structs (define `t()` type)

```elixir
@type t :: %__MODULE__{
  id: integer(),
  scientific_name: String.t(),
  author: String.t() | nil,
  is_hybrid: boolean(),
  subgenus: String.t() | nil
}
```

Use `| nil` for fields that can be null in the database or associations that may not be loaded.

---

## Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Modules | PascalCase | `OaksWeb.SpeciesDetailLive` |
| Functions | snake_case | `get_species_by_name/1` |
| Variables | snake_case | `species_list` |
| Atoms | snake_case | `:species_created` |
| Files | snake_case | `species_detail_live.ex` |
| LiveView modules | `*Live` suffix | `SpeciesListLive`, `TaxonomyLive` |
| Context modules | Plural noun | `Species`, `Sources`, `Articles` |
| Schema modules | Singular noun | `Species.Species`, `Sources.Source` |

**Predicate functions** end with `?`:
```elixir
def valid?(changeset), do: changeset.valid?
```

**Never** prefix predicates with `is_`:
```elixir
# WRONG
def is_valid(changeset)

# CORRECT
def valid?(changeset)
```

---

## Code Organization

### Phoenix Contexts

Organize business logic into contexts (domain modules):

```
lib/oaks/
├── species.ex         # Species context (public API)
├── species/
│   └── species.ex     # Species schema
├── taxonomy.ex        # Taxonomy context
├── taxonomy/
│   └── taxon.ex       # Taxon schema
├── sources.ex         # Sources context
├── sources/
│   ├── source.ex      # Source schema
│   └── species_source.ex  # SpeciesSource schema
└── articles.ex        # Articles context
    └── articles/
        └── article.ex # Article schema
```

**Context modules** expose the public API. **Schema modules** define data structures.

### Keep Related Code Together

- One module per file
- Files mirror module namespace (`Oaks.Species.Species` → `lib/oaks/species/species.ex`)
- Tests mirror source structure (`lib/oaks/species.ex` → `test/oaks/species_test.exs`)

---

## Ecto Patterns

### Queries

Use Ecto's query syntax, not raw SQL:

```elixir
def list_species_by_subgenus(subgenus) do
  from(s in Species,
    where: s.subgenus == ^subgenus,
    order_by: [asc: s.scientific_name]
  )
  |> Repo.all()
end
```

### Changesets

Define changesets in schema modules:

```elixir
def changeset(species, attrs) do
  species
  |> cast(attrs, [:scientific_name, :author, :is_hybrid, :subgenus, :section])
  |> validate_required([:scientific_name])
  |> unique_constraint(:scientific_name)
end
```

**Never** put user-input fields and programmatic fields in the same `cast/3`:

```elixir
# User input
|> cast(attrs, [:scientific_name, :author])
# Then set programmatic fields explicitly
|> put_change(:updated_at, DateTime.utc_now())
```

### Preloading

Always preload associations that will be accessed:

```elixir
# In context
species = Repo.get(Species, id) |> Repo.preload([:species_sources])

# Or in query
from(s in Species, preload: [:species_sources])
```

### Avoiding N+1 Queries

N+1 occurs when you query a list, then query each item's association separately:

```elixir
# BAD - N+1 (1 query for species, N queries for sources)
species = Repo.all(Species)
Enum.map(species, fn s -> s.species_sources end)  # Each access triggers a query

# GOOD - Preload in the original query
species = Repo.all(from s in Species, preload: [:species_sources])
Enum.map(species, fn s -> s.species_sources end)  # No additional queries
```

**Detection:** Enable query logging in dev to spot repeated queries:
```elixir
# config/dev.exs
config :oaks, Oaks.Repo, log: :debug
```

### SQLite Compatibility

SQLite does not support `ilike`. Use fragments for case-insensitive search:

```elixir
# WRONG - PostgreSQL only
where: ilike(s.scientific_name, ^search_term)

# CORRECT - SQLite compatible
search_term = "%#{String.downcase(query)}%"
where: fragment("lower(?) LIKE ?", s.scientific_name, ^search_term)
```

### Query Performance

- Use `select` to fetch only needed fields for large result sets
- Add database indexes for frequently filtered/joined columns
- Use `Repo.stream/1` for processing large datasets without loading all into memory

---

## LiveView Patterns

### Streams for Collections

Use streams for lists to avoid memory issues:

```elixir
def mount(_params, _session, socket) do
  {:ok, stream(socket, :species, Species.list_species())}
end
```

```heex
<div id="species-list" phx-update="stream">
  <div :for={{id, species} <- @streams.species} id={id}>
    {species.scientific_name}
  </div>
</div>
```

### Forms

Always use `to_form/2` and the `<.input>` component:

```elixir
def mount(_params, _session, socket) do
  changeset = Species.change_species(%Species{})
  {:ok, assign(socket, form: to_form(changeset))}
end
```

```heex
<.form for={@form} id="species-form" phx-change="validate" phx-submit="save">
  <.input field={@form[:scientific_name]} type="text" label="Scientific Name" />
  <.button>Save</.button>
</.form>
```

### Function Components vs LiveComponents

**Function components** (default choice) are simple, stateless, and render as part of the parent:

```elixir
# In core_components.ex or any module
attr :name, :string, required: true
def species_badge(assigns) do
  ~H"""
  <span class="badge">{@name}</span>
  """
end
```

**LiveComponents** have their own state and event handling. Only use when you need:
- Independent state that shouldn't re-render with parent
- Isolated event handling (`handle_event` in the component)
- Performance isolation for expensive renders

**Rule of thumb:** Start with function components. Convert to LiveComponent only when you hit a specific limitation.

### JavaScript Interop

When using `phx-hook`, follow these rules:

```heex
<%!-- Hook that manages its own DOM must use phx-update="ignore" --%>
<div id="chart" phx-hook="Chart" phx-update="ignore"></div>

<%!-- Always provide a unique DOM id with phx-hook --%>
<input id="phone-input" phx-hook="PhoneFormatter" />
```

**Colocated hooks** (Phoenix 1.8+) keep JS close to the template:

```heex
<input type="text" id="phone" phx-hook=".PhoneNumber" />
<script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
  export default {
    mounted() {
      this.el.addEventListener("input", e => {
        // format phone number
      })
    }
  }
</script>
```

- Colocated hook names **must** start with a `.` prefix (e.g., `.PhoneNumber`)
- Never write raw `<script>` tags - use colocated hooks or external JS

**External hooks** go in `assets/js/` and register with LiveSocket:

```javascript
// assets/js/hooks.js
export const Chart = {
  mounted() {
    this.chart = new Chart(this.el, {...})
  },
  updated() {
    this.chart.update()
  },
  destroyed() {
    this.chart.destroy()
  }
}

// assets/js/app.js
import { Chart } from "./hooks"
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { Chart }
})
```

---

## Error Handling

### Pattern Match Results

Handle success and error cases explicitly:

```elixir
case Species.create_species(attrs) do
  {:ok, species} ->
    {:noreply,
     socket
     |> put_flash(:info, "Species created")
     |> push_navigate(to: ~p"/species/#{species.scientific_name}")}

  {:error, changeset} ->
    {:noreply, assign(socket, form: to_form(changeset))}
end
```

### Use `with` for Multi-Step Operations

Use `with` when chaining 2+ operations that can fail. For single checks, prefer `case`.

```elixir
with %Species{} = species <- Repo.get_by(Species, scientific_name: name),
     :ok <- authorize(user, :update, species),
     {:ok, updated} <- Species.update_species(species, attrs) do
  {:ok, updated}
else
  nil -> {:error, :not_found}
  {:error, reason} -> {:error, reason}
end
```

**Note**: Match on actual return types. `Repo.get/2` returns `struct | nil`, not `{:ok, struct}`.

---

## Testing

### Test File Structure

```elixir
defmodule Oaks.SpeciesTest do
  use Oaks.DataCase

  alias Oaks.Species

  describe "list_species/0" do
    test "returns all species" do
      species = species_fixture()
      assert Species.list_species() == [species]
    end
  end
end
```

### LiveView Tests

Use `Phoenix.LiveViewTest`:

```elixir
defmodule OaksWeb.SpeciesListLiveTest do
  use OaksWeb.ConnCase

  import Phoenix.LiveViewTest

  test "displays species list", %{conn: conn} do
    species = species_fixture()
    {:ok, view, _html} = live(conn, ~p"/list")
    assert has_element?(view, "#species-#{species.id}")
  end
end
```

### Fixtures

Test fixtures are defined in `test/support/fixtures/` and imported via `DataCase` or `ConnCase`:

```elixir
defmodule Oaks.SpeciesFixtures do
  def species_fixture(attrs \\ %{}) do
    {:ok, species} =
      attrs
      |> Enum.into(%{scientific_name: "alba", is_hybrid: false})
      |> Oaks.Species.create_species()

    species
  end
end
```

Import in tests: `import Oaks.SpeciesFixtures`

### Assertions

- Use `assert` and `refute`, not `assert x == true`
- Test behavior, not implementation
- Use fixtures for test data (define in `test/support/fixtures/`)
- Reference elements by ID: `has_element?(view, "#my-element")`

---

## Logging

Use the `Logger` module with appropriate levels:

```elixir
require Logger

Logger.debug("Query executed", sql: query, params: params)  # Development details
Logger.info("Species created", name: species.scientific_name) # Significant events
Logger.warning("Rate limit approaching", count: count)        # Unexpected but recoverable
Logger.error("Import failed", error: reason)                  # Failures requiring attention
```

**Guidelines:**
- Use structured metadata (keyword lists) over string interpolation
- Never log PII (emails, passwords, tokens, full names)
- Use `debug` for high-volume or detailed tracing
- Use `info` for business events (user actions, state changes)
- Use `warning` for recoverable issues
- Use `error` for failures that need investigation

---

## OTP Patterns

For background work, prefer the simplest tool that fits:

| Need | Use | Example |
|------|-----|---------|
| One-off async work | `Task.async/1` or `Task.Supervisor` | Sending emails |
| Periodic work | `Process.send_after/3` in GenServer | Cache expiration |
| Stateful process | `GenServer` | Connection pool, rate limiter |
| Simple state | `Agent` | Counters, simple caches |

**GenServer basics:**

```elixir
defmodule Oaks.Counter do
  use GenServer

  # Client API
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def increment, do: GenServer.call(__MODULE__, :increment)

  # Server callbacks
  @impl true
  def init(_opts), do: {:ok, 0}

  @impl true
  def handle_call(:increment, _from, count), do: {:reply, count + 1, count + 1}
end
```

**Notes:**
- Always add GenServers to a supervision tree
- Use `@impl true` for callback functions
- Prefer named processes (`name: __MODULE__`) for singletons

---

## Security

Phoenix provides strong defaults. Don't disable them without understanding the risks.

### CSRF Protection

Phoenix forms include CSRF tokens automatically. Never:
- Disable `Plug.CSRFProtection` in router
- Use `raw` to bypass token insertion
- Accept form data without `phx-submit` or standard form POST

### Input Handling

```elixir
# SAFE - Ecto parameterizes values
from(s in Species, where: s.scientific_name == ^user_input)

# DANGEROUS - SQL injection risk
from(s in Species, where: fragment("scientific_name = '#{user_input}'"))

# SAFE - Use parameterized fragments
from(s in Species, where: fragment("lower(?) LIKE ?", s.scientific_name, ^pattern))
```

### HTML Output

```heex
<%!-- SAFE - Phoenix escapes by default --%>
<p>{@user_comment}</p>

<%!-- DANGEROUS - Only use for trusted HTML (admin-generated markdown, etc.) --%>
<p>{raw(@trusted_html)}</p>
```

### Atom Creation

```elixir
# DANGEROUS - Atoms are never garbage collected
String.to_atom(user_input)

# SAFE - Only creates existing atoms
String.to_existing_atom(user_input)
```

---

## Configuration

Phoenix uses multiple config files for different purposes:

| File | When Evaluated | Use For |
|------|----------------|---------|
| `config/config.exs` | Compile time | Shared settings, imported by all envs |
| `config/dev.exs` | Compile time | Dev-only settings (debug, local URLs) |
| `config/test.exs` | Compile time | Test settings (async, test DB) |
| `config/prod.exs` | Compile time | Production defaults (not secrets) |
| `config/runtime.exs` | Runtime | **Secrets**, env vars, dynamic config |

**Key rules:**
- Secrets (API keys, `SECRET_KEY_BASE`, DB credentials) go in `runtime.exs`
- Never commit secrets to `prod.exs`
- Use `System.get_env/1` only in `runtime.exs`

```elixir
# config/runtime.exs
if config_env() == :prod do
  config :oaks, Oaks.Repo,
    database: System.get_env("DATABASE_PATH") || "/data/oaks.db"
end
```

---

## Phoenix 1.8 Patterns

Phoenix 1.8 introduced several conventions. Follow these patterns for consistency.

### Layout Wrapping

LiveView templates should begin with `<Layouts.app>`:

```heex
<Layouts.app flash={@flash}>
  <h1>Page Title</h1>
  <!-- page content -->
</Layouts.app>
```

The `Layouts` module is auto-aliased in `oaks_web.ex` - no explicit alias needed.

### Flash Messages

The `<.flash_group>` component lives in `layouts.ex` and renders automatically. **Never** call `<.flash_group>` directly in LiveView templates - it's handled by the layout.

### Icons

Use the `<.icon>` component from `core_components.ex`:

```heex
<.icon name="hero-x-mark" class="w-5 h-5" />
<.icon name="hero-check" class="w-4 h-4 text-green-500" />
```

**Never** use external Heroicons packages or inline SVGs for standard icons.

### Form Inputs

Use the `<.input>` component from `core_components.ex`:

```heex
<.input field={@form[:scientific_name]} type="text" label="Scientific Name" />
<.input field={@form[:subgenus]} type="select" options={["Quercus", "Cerris", "Lobatae"]} />
```

**Note:** If you override input classes with the `class` attribute, no default styles are inherited - your classes must fully style the input.

---

## HEEx Templates

HEEx (HTML + Elixir) is Phoenix's template syntax. Use `~H` sigils or `.heex` files.

### Interpolation

Use `{...}` for values in attributes and text:

```heex
<div class={@class}>Hello, {@name}!</div>
<img src={@image_url} alt={@alt_text} />
```

Use `<%= %>` only for block constructs:

```heex
<%= if @show do %>
  <p>Visible</p>
<% end %>

<%= for item <- @items do %>
  <li>{item.name}</li>
<% end %>
```

### Conditional Classes

HEEx supports list syntax for conditional classes:

```heex
<div class={[
  "base-class px-4",
  @active && "bg-blue-500",
  @disabled && "opacity-50 cursor-not-allowed",
  if(@size == :large, do: "text-xl", else: "text-base")
]}>
  Content
</div>
```

`nil` and `false` values are filtered out automatically.

### Comments

```heex
<%!-- This is an HEEx comment (not rendered in HTML) --%>

<!-- This is an HTML comment (visible in page source) -->
```

### The `:for` Attribute

Prefer `:for` over `<%= for %>` blocks:

```heex
<%!-- Preferred --%>
<li :for={item <- @items} id={"item-#{item.id}"}>
  {item.name}
</li>

<%!-- Avoid --%>
<%= for item <- @items do %>
  <li id={"item-#{item.id}"}>{item.name}</li>
<% end %>
```

### The `:if` Attribute

Prefer `:if` for simple conditionals:

```heex
<%!-- Preferred --%>
<span :if={@show_badge} class="badge">{@count}</span>

<%!-- Use <%= if %> for if/else --%>
<%= if @logged_in do %>
  <span>Welcome back!</span>
<% else %>
  <.link href={~p"/login"}>Sign in</.link>
<% end %>
```

---

## Assets & Styling

### Asset Bundles

Phoenix uses esbuild for JavaScript and Tailwind for CSS. Only two bundles are supported:

- `assets/js/app.js` → compiled to `priv/static/assets/app.js`
- `assets/css/app.css` → compiled to `priv/static/assets/app.css`

**Rules:**
- Never reference external script `src` or stylesheet `href` in layouts
- Import vendor dependencies into `app.js` or `app.css`
- Never write inline `<script>` tags (use hooks instead)

### Tailwind CSS v4

Tailwind v4 uses CSS-based configuration (no `tailwind.config.js`):

```css
/* assets/css/app.css */
@import "tailwindcss";

@theme {
  --color-brand: #5b7a3a;
  --color-danger: #dc2626;
}
```

**Rules:**
- Never use `@apply` - compose utilities in templates instead
- Define custom colors/values in `@theme` blocks
- Use standard Tailwind classes in HEEx templates

---

## Things to Avoid

| Don't | Do Instead |
|-------|------------|
| `String.to_atom(user_input)` | Use existing atoms or `String.to_existing_atom/1` |
| Nested modules in same file | One module per file |
| `<%= for %>` blocks in HEEx | `:for` attribute: `<div :for={item <- @items}>` |
| `live_redirect`/`live_patch` | `push_navigate`/`push_patch` or `<.link>` |
| Raw `<script>` tags | Colocated hooks or external JS |
| `ilike` in queries | `fragment("lower(?) LIKE ?", ...)` for SQLite |
| Map access on structs | Dot notation: `struct.field` |
| `Process.sleep` in tests | `Process.monitor` or proper synchronization |

---

## Pre-Commit Checklist

Before committing:

1. `mix format` - Format all code
2. `mix compile --warnings-as-errors` - No compilation warnings
3. `mix credo --strict` - No Credo issues
4. `mix test` - All tests pass
5. `mix dialyzer` - No type errors

Or run: `mix precommit` (if configured)
