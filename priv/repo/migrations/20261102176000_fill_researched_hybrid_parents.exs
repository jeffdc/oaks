defmodule Oaks.Repo.Migrations.FillResearchedHybridParents do
  @moduledoc """
  Fills parents for named hybrids from Jeff's 2026-11 parentage research
  (POWO/WCVP, Oaks of the World, IPNI, WFO, FNA), plus his decisions on the
  disputed ones (× mannifera and × subpyrenaica follow POWO). × cerrioides
  keeps canariensis × pubescens from SplitOaksOfTheWorldSynonyms.
  × columnaris and × subglaucescens are merged into × richteri and × anselmii
  by MergePowoSynonymHybrids.

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
    # Camus / Oaks of the World; POWO calls this cross × prasina instead.
    {"× battandieri", "coccifera", "faginea broteroi"},
    {"× carrissoana", "canariensis", "robur"},
    {"× celtica", "lusitanica", "suber"},
    {"× coscojosuberiformis", "coccifera", "suber"},
    # Replacement name for the illegitimate × grandidentata Ewan
    {"× ewanii", "durata gabrielensis", "engelmannii"},
    # Protologue / Oaks of the World (POWO: lusitanica × orocantabrica)
    {"× gallaecica", "lusitanica", "robur"},
    # Conventional formula; 2018 genetics suggests it may be an ancestral form.
    {"× hispanica", "cerris", "suber"},
    # robur × pubescens subsp. subpyrenaica (no subpyrenaica row here)
    {"× kerneri montserratii", "robur", "pubescens"},
    # POWO: coccolobifolia × viminea, coccolobifolia = jonesii
    {"× knoblochii", "jonesii", "viminea"},
    # POWO. Older literature: boissieri × iberica; Avishai 2015: a distinct species.
    {"× mannifera", "infectoria veneris", "petraea polycarpa"},
    {"× numantina", "faginea", "pyrenaica"},
    {"× pachucana", "laurina", "mexicana"},
    {"× schochiana", "palustris", "phellos"},
    {"× subconvexa", "durata", "garryana"},
    # POWO. WFO and Oaks of the World treat it as Q. pubescens subsp. subpyrenaica.
    {"× subpyrenaica", "faginea", "pubescens"},
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
