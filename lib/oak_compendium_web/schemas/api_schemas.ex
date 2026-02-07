defmodule OakCompendiumWeb.Schemas do
  @moduledoc """
  OpenAPI schema definitions for the Oak Compendium API.
  """

  alias OpenApiSpex.Schema

  # -- Error --

  defmodule Error do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Error",
      type: :object,
      properties: %{
        error: %Schema{type: :string, description: "Error message"}
      },
      required: [:error]
    })
  end

  # -- Species --

  defmodule Species do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Species",
      description: "An oak species or hybrid",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        scientific_name: %Schema{type: :string},
        author: %Schema{type: :string, nullable: true},
        is_hybrid: %Schema{type: :boolean},
        conservation_status: %Schema{type: :string, nullable: true},
        subgenus: %Schema{type: :string, nullable: true},
        section: %Schema{type: :string, nullable: true},
        subsection: %Schema{type: :string, nullable: true},
        complex: %Schema{type: :string, nullable: true},
        parent1: %Schema{type: :string, nullable: true},
        parent2: %Schema{type: :string, nullable: true},
        hybrids: %Schema{type: :array, items: %Schema{type: :string}},
        closely_related_to: %Schema{type: :array, items: %Schema{type: :string}},
        subspecies_varieties: %Schema{type: :array, items: %Schema{type: :string}},
        synonyms: %Schema{type: :array, items: %Schema{type: :string}},
        external_links: %Schema{type: :array, items: %Schema{type: :string}}
      },
      required: [:id, :scientific_name, :is_hybrid]
    })
  end

  defmodule SpeciesSourceData do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SpeciesSourceData",
      description: "Source-specific data for a species",
      type: :object,
      properties: %{
        source_id: %Schema{type: :integer},
        source_name: %Schema{type: :string},
        source_url: %Schema{type: :string, nullable: true},
        is_preferred: %Schema{type: :boolean},
        local_names: %Schema{type: :array, items: %Schema{type: :string}},
        range: %Schema{type: :string, nullable: true},
        growth_habit: %Schema{type: :string, nullable: true},
        leaves: %Schema{type: :string, nullable: true},
        flowers: %Schema{type: :string, nullable: true},
        fruits: %Schema{type: :string, nullable: true},
        bark: %Schema{type: :string, nullable: true},
        twigs: %Schema{type: :string, nullable: true},
        buds: %Schema{type: :string, nullable: true},
        hardiness_habitat: %Schema{type: :string, nullable: true},
        miscellaneous: %Schema{type: :string, nullable: true},
        url: %Schema{type: :string, nullable: true}
      },
      required: [:source_id, :source_name, :is_preferred]
    })
  end

  defmodule SpeciesFull do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SpeciesFull",
      description: "A species with all source data",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        scientific_name: %Schema{type: :string},
        author: %Schema{type: :string, nullable: true},
        is_hybrid: %Schema{type: :boolean},
        conservation_status: %Schema{type: :string, nullable: true},
        subgenus: %Schema{type: :string, nullable: true},
        section: %Schema{type: :string, nullable: true},
        subsection: %Schema{type: :string, nullable: true},
        complex: %Schema{type: :string, nullable: true},
        parent1: %Schema{type: :string, nullable: true},
        parent2: %Schema{type: :string, nullable: true},
        hybrids: %Schema{type: :array, items: %Schema{type: :string}},
        closely_related_to: %Schema{type: :array, items: %Schema{type: :string}},
        subspecies_varieties: %Schema{type: :array, items: %Schema{type: :string}},
        synonyms: %Schema{type: :array, items: %Schema{type: :string}},
        external_links: %Schema{type: :array, items: %Schema{type: :string}},
        sources: %Schema{
          type: :array,
          items: OakCompendiumWeb.Schemas.SpeciesSourceData
        }
      },
      required: [:id, :scientific_name, :is_hybrid, :sources]
    })
  end

  defmodule SpeciesListResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SpeciesListResponse",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: OakCompendiumWeb.Schemas.Species},
        count: %Schema{type: :integer},
        limit: %Schema{type: :integer},
        offset: %Schema{type: :integer}
      },
      required: [:data, :count, :limit, :offset]
    })
  end

  # -- Taxon --

  defmodule Taxon do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Taxon",
      description: "A taxonomic rank (subgenus, section, subsection, complex)",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        name: %Schema{type: :string},
        level: %Schema{
          type: :string,
          enum: ["subgenus", "section", "subsection", "complex"]
        },
        parent: %Schema{type: :string, nullable: true},
        author: %Schema{type: :string, nullable: true},
        content: %Schema{type: :string, nullable: true},
        content_updated_at: %Schema{type: :string, nullable: true},
        links: %Schema{nullable: true}
      },
      required: [:id, :name, :level]
    })
  end

  # -- Source --

  defmodule Source do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Source",
      description: "A data source (website, book, personal observation)",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        source_type: %Schema{type: :string},
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        author: %Schema{type: :string, nullable: true},
        year: %Schema{type: :integer, nullable: true},
        url: %Schema{type: :string, nullable: true},
        isbn: %Schema{type: :string, nullable: true},
        doi: %Schema{type: :string, nullable: true},
        notes: %Schema{type: :string, nullable: true},
        license: %Schema{type: :string, nullable: true},
        license_url: %Schema{type: :string, nullable: true}
      },
      required: [:id, :source_type, :name]
    })
  end

  # -- Article --

  defmodule Article do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Article",
      description: "A reference article or guide",
      type: :object,
      properties: %{
        id: %Schema{type: :integer},
        slug: %Schema{type: :string},
        title: %Schema{type: :string},
        author: %Schema{type: :string},
        content: %Schema{type: :string, nullable: true},
        tags: %Schema{type: :array, items: %Schema{type: :string}},
        is_published: %Schema{type: :boolean},
        created_at: %Schema{type: :string},
        updated_at: %Schema{type: :string},
        published_at: %Schema{type: :string, nullable: true}
      },
      required: [:id, :slug, :title, :author]
    })
  end

  # -- Search --

  defmodule SearchResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SearchResponse",
      description: "Unified search results across entity types",
      type: :object,
      properties: %{
        species: %Schema{type: :array, items: %Schema{type: :object}},
        taxa: %Schema{type: :array, items: %Schema{type: :object}},
        sources: %Schema{type: :array, items: %Schema{type: :object}}
      },
      required: [:species, :taxa, :sources]
    })
  end

  # -- Stats --

  defmodule StatsResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "StatsResponse",
      description: "Aggregate database statistics",
      type: :object,
      properties: %{
        species_count: %Schema{type: :integer},
        hybrid_count: %Schema{type: :integer},
        taxa_count: %Schema{type: :integer},
        source_count: %Schema{type: :integer}
      },
      required: [:species_count, :hybrid_count, :taxa_count, :source_count]
    })
  end

  # -- Health --

  defmodule HealthResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "HealthResponse",
      description: "Health check response",
      type: :object,
      properties: %{
        status: %Schema{type: :string}
      },
      required: [:status]
    })
  end

  # -- Auth --

  defmodule AuthVerifyResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AuthVerifyResponse",
      description: "Auth verification response",
      type: :object,
      properties: %{
        authenticated: %Schema{type: :boolean}
      },
      required: [:authenticated]
    })
  end
end
