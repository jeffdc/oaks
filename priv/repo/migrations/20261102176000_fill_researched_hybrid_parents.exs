defmodule Oaks.Repo.Migrations.FillResearchedHybridParents do
  @moduledoc """
  Fills parents for named hybrids from Jeff's 2026-11 parentage research
  (POWO/WCVP, Oaks of the World, IPNI, WFO, FNA). Only hybrids with an
  uncontested formula are here; disputed ones are left for a decision.

  Infraspecific parents use the existing infraspecific species row when there
  is one (e.g. `durata gabrielensis`), otherwise the species. A row is only
  updated while it has no parents and both parent names exist, so this is a
  no-op elsewhere and when run again. Runs before NormalizeSpeciesLists, which
  adds the parents' back-links.
  """
  use Ecto.Migration

  # {hybrid, parent1, parent2}
  @parents [
    {"× avellaniformis", "rotundifolia", "suber"},
    {"× carrissoana", "canariensis", "robur"},
    {"× celtica", "lusitanica", "suber"},
    # POWO: synonym of × richteri (palustris × rubra)
    {"× columnaris", "palustris", "rubra"},
    {"× coscojosuberiformis", "coccifera", "suber"},
    # Replacement name for the illegitimate × grandidentata Ewan
    {"× ewanii", "durata gabrielensis", "engelmannii"},
    # robur × pubescens subsp. subpyrenaica (no subpyrenaica row here)
    {"× kerneri montserratii", "robur", "pubescens"},
    # POWO: coccolobifolia × viminea, coccolobifolia = jonesii
    {"× knoblochii", "jonesii", "viminea"},
    {"× numantina", "faginea", "pyrenaica"},
    {"× pachucana", "laurina", "mexicana"},
    {"× schochiana", "palustris", "phellos"},
    {"× subconvexa", "durata", "garryana"},
    # POWO: synonym of × anselmii (canariensis × pubescens)
    {"× subglaucescens", "canariensis", "pubescens"},
    {"× takaoyamensis", "acuta", "sessilifolia"},
    {"× tingitana", "faginea", "lusitanica"},
    {"× welwitschii", "estremadurensis", "pyrenaica"}
  ]

  def up do
    for {hybrid, parent1, parent2} <- @parents do
      repo().query!(
        """
        UPDATE species SET parent1 = ?2, parent2 = ?3
        WHERE scientific_name = ?1
          AND COALESCE(parent1, '') = '' AND COALESCE(parent2, '') = ''
          AND EXISTS (SELECT 1 FROM species WHERE scientific_name = ?2)
          AND EXISTS (SELECT 1 FROM species WHERE scientific_name = ?3)
        """,
        [hybrid, parent1, parent2]
      )
    end
  end

  def down, do: :ok
end
