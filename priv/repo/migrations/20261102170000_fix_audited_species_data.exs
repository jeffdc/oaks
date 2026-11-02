defmodule Oaks.Repo.Migrations.FixAuditedSpeciesData do
  @moduledoc """
  One-time targeted data fixes from the 2026-11 audit, reviewed by hand.

  Each statement matches the exact bad value it corrects, so it changes
  nothing on other rows, on an empty database, or when run again. Runs just
  before NormalizeSpeciesLists, whose back-link step then adds corrected
  parents' `hybrids` entries.
  """
  use Ecto.Migration

  # {species, column, bad value, corrected value}
  @parent_typos [
    {"× drummondii", "parent1", "margaretta", "margaretiae"},
    {"× introgressa", "parent2", "prinoïdes", "prinoides"},
    {"× munzii", "parent2", "cornelius", "cornelius-mulleri"}
  ]

  # Full literature citations stored as the author; keep only the authority.
  @author_trims [
    {"brantii", "Lindl. 1840", "Lindl."},
    {"cocciferoides", "Hand.-Mazz. 1925", "Hand.-Mazz."},
    {"eumorpha", "Kurz 1873", "Kurz"},
    {"rysophylla", "Weath. 1910", "Weath."},
    {"serrata", "Murray 1784", "Murray"},
    {"× tingitana", "A.Camus", "A.Camus"}
  ]

  # Subsections used by species but missing from taxa: {name, parent section}
  @missing_subsections [
    {"Erythromexicanae", "Lobatae"},
    {"Leucomexicanae", "Quercus"},
    {"Salicifoliae", "Lobatae"}
  ]

  # Synonym entries that are scraper fragments or bare notes, not names
  @junk_synonyms %{
    "buckleyi" => ["nom. illeg."],
    "chrysotricha" => ["not Hick. & A.Camus 1936"],
    "coahuilensis" => ["not Trel. 1924"],
    "flocculenta" => ["nom. inval."],
    "invaginata" => ["nom. inval."],
    "ithaburensis" => ["look"],
    "petraea" => ["mas"],
    "× diegoi" => ["4-6 m", "5-6(7) x 1-3", "5(4", "2) cm"],
    "× morehus" => ["nom. illeg."],
    "× walteriana" => ["not Q. sinuata Walt 1788"]
  }

  def up do
    for {species, column, bad, good} <- @parent_typos do
      repo().query!(
        "UPDATE species SET #{column} = ?1 WHERE scientific_name = ?2 AND #{column} = ?3",
        [good, species, bad]
      )
    end

    # falcata isn't a hybrid; its author "Mich 1803" was split into the parent
    # columns and truncated in the author column.
    repo().query!("""
    UPDATE species SET author = 'Michx.', parent1 = NULL, parent2 = NULL
    WHERE scientific_name = 'falcata' AND author = 'Mich' AND parent1 = 'Mich' AND parent2 = '1803'
    """)

    # Its genus and epithet (Cyclobalanopsis takaoyamensis) were parsed as parents.
    repo().query!("""
    UPDATE species SET parent1 = NULL, parent2 = NULL
    WHERE scientific_name = '× takaoyamensis'
      AND parent1 = 'Cyclobalanopsis' AND parent2 = 'takaoyamensis'
    """)

    for {species, prefix, authority} <- @author_trims do
      repo().query!(
        "UPDATE species SET author = ?1 WHERE scientific_name = ?2 AND author LIKE ?3 AND author != ?1",
        [authority, species, prefix <> "%"]
      )
    end

    for {name, section} <- @missing_subsections do
      repo().query!(
        """
        INSERT INTO taxa (name, level, parent)
        SELECT ?1, 'subsection', ?2
        WHERE EXISTS (SELECT 1 FROM species WHERE subsection = ?1 AND section = ?2)
          AND NOT EXISTS (SELECT 1 FROM taxa WHERE name = ?1 AND level = 'subsection')
        """,
        [name, section]
      )
    end

    # "Roburoid" isn't a subsection; the species is already in the robur complex,
    # which sits directly under section Quercus.
    repo().query!("""
    UPDATE species SET subsection = NULL
    WHERE scientific_name = 'orocantabrica' AND subsection = 'Roburoid' AND complex = 'robur'
    """)

    fill_formula_hybrid_parents()
    rename_ascii_x_hybrids()
    remove_junk_synonyms()
  end

  def down, do: :ok

  # Formula-named hybrids ("agrifolia × parvula") with no parents recorded get
  # them from the name, when both names are existing species.
  defp fill_formula_hybrid_parents do
    %{rows: names} = repo().query!("SELECT scientific_name FROM species")
    existing = MapSet.new(names, fn [name] -> name end)

    %{rows: rows} =
      repo().query!("""
      SELECT id, scientific_name FROM species
      WHERE is_hybrid = 1 AND COALESCE(parent1, '') = '' AND COALESCE(parent2, '') = ''
      """)

    for [id, name] <- rows,
        [parent1, parent2] <- [String.split(name, ~r/\s[×x]\s/u)],
        MapSet.member?(existing, parent1) and MapSet.member?(existing, parent2) do
      repo().query!("UPDATE species SET parent1 = ?1, parent2 = ?2 WHERE id = ?3", [
        parent1,
        parent2,
        id
      ])
    end
  end

  # Two formula hybrids use an ASCII "x". Nothing references them; keep the old
  # names as synonyms so existing links still resolve.
  defp rename_ascii_x_hybrids do
    for old <- ["berberidifolia x cornelius-mulleri", "dumosa x engelmannii"] do
      new = String.replace(old, " x ", " × ")

      repo().query!(
        """
        UPDATE species
        SET scientific_name = ?1,
            synonyms = json_insert(COALESCE(NULLIF(synonyms, 'null'), '[]'), '$[#]', ?2)
        WHERE scientific_name = ?2
          AND NOT EXISTS (SELECT 1 FROM species WHERE scientific_name = ?1)
        """,
        [new, old]
      )
    end
  end

  defp remove_junk_synonyms do
    for {species, junk} <- @junk_synonyms,
        [id, raw] <- species_synonyms(species),
        {:ok, list} when is_list(list) <- [Jason.decode(raw)],
        (kept = Enum.reject(list, &(is_binary(&1) and collapse(&1) in junk))) != list do
      value = if kept == [], do: nil, else: Jason.encode!(kept)
      repo().query!("UPDATE species SET synonyms = ?1 WHERE id = ?2", [value, id])
    end
  end

  defp species_synonyms(species) do
    %{rows: rows} =
      repo().query!(
        "SELECT id, synonyms FROM species WHERE scientific_name = ?1 AND synonyms IS NOT NULL",
        [species]
      )

    rows
  end

  defp collapse(text), do: text |> String.split() |> Enum.join(" ")
end
