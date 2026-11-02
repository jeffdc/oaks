defmodule Oaks.Repo.Migrations.SplitOaksOfTheWorldSynonyms do
  @moduledoc """
  One-time cleanup of synonyms scraped from Oaks of the World (2026-11 audit).

  The scraper ran several names together into one synonym entry, split notes
  ("nom. illeg.", "non Lam. 1785") off from the name they belong to, kept
  hybrid parentage formulas ("pacifica x lobata = ...") as synonyms, and
  stored × diegoi's Latin description as synonyms. Each fix below was
  reviewed by hand: the listed entries (compared with whitespace collapsed)
  are replaced by the corrected ones, in place.

  Runs before NormalizeSpeciesLists, which then re-encodes the lists and adds
  back-links for the hybrid parents filled in here. Rows that no longer match
  are left alone, so this is a no-op on other databases and when run again.
  """
  use Ecto.Migration

  # {species, entries to replace, replacement entries}
  @splits [
    {"aculcingensis",
     [
       "reticulata var. retifolia Liebm. 1869 reticulata var. crassifolia Oerst. in Liebm. 1869"
     ],
     [
       "reticulata var. retifolia Liebm. 1869",
       "reticulata var. crassifolia Oerst. in Liebm. 1869"
     ]},
    {"argentata",
     [
       "Cyclobalanopsis argentata (Korth.) Oerst. 1867 pinanga Bl. 1851 wilhelminae Seemen 1906 Lithocarpus argentatus (Korth.) Merr. 1934"
     ],
     [
       "Cyclobalanopsis argentata (Korth.) Oerst. 1867",
       "pinanga Bl. 1851",
       "wilhelminae Seemen 1906",
       "Lithocarpus argentatus (Korth.) Merr. 1934"
     ]},
    {"berberidifolia",
     [
       "dumosa Nuttall 1842 in part agrifolia var. berberidifolia (Liebm.) Wenz. 1884 dumosa f. berberidifolia (Liebm.) Trel. 1924 dumosa var. munita Greene 1889"
     ],
     [
       "dumosa Nuttall 1842 in part",
       "agrifolia var. berberidifolia (Liebm.) Wenz. 1884",
       "dumosa f. berberidifolia (Liebm.) Trel. 1924",
       "dumosa var. munita Greene 1889"
     ]},
    {"camusiae",
     [
       "geminata Hickel & A. Camus 1923 nom. illegit. not Small Cyclobalanopsis camusiae (Trel. ex Hickel & A. Camus)Y.C. Hsu & H.W. Jen 1993"
     ],
     [
       "geminata Hickel & A. Camus 1923 nom. illegit. not Small",
       "Cyclobalanopsis camusiae (Trel. ex Hickel & A. Camus) Y.C. Hsu & H.W. Jen 1993"
     ]},
    {"chenii",
     [
       "acutissima subsp chenii (Nakai) A.Camus 1934 acutissima var. chenii (Nak.) Menitsky 1973 acutissima var. brevipetioleata C.Ho 1952 chenii var. linanensis M.C.Liu & X.L.Shenin 1992"
     ],
     [
       "acutissima subsp chenii (Nakai) A.Camus 1934",
       "acutissima var. chenii (Nak.) Menitsky 1973",
       "acutissima var. brevipetioleata C.Ho 1952",
       "chenii var. linanensis M.C.Liu & X.L.Shenin 1992"
     ]},
    {"convallata",
     [
       "reticulata f. inclusa (Trel.) A.Camus 1935 reticulata f. apus (Trel.) A.Camus 1935 rhodophlebia f. inclusa Trel. 1924 rhodophlebia f. apus Trel. 1924"
     ],
     [
       "reticulata f. inclusa (Trel.) A.Camus 1935",
       "reticulata f. apus (Trel.) A.Camus 1935",
       "rhodophlebia f. inclusa Trel. 1924",
       "rhodophlebia f. apus Trel. 1924"
     ]},
    {"estremadurensis",
     [
       "robur subsp. estremadurensis (O. Schwarz) A. Camus 1935 racemosa Brot. 1804 non Lam. 1785 robur subsp. broteroana auct. pl. non Schwarz 1935 robur var. conimbricensis Camus 1934"
     ],
     [
       "robur subsp. estremadurensis (O. Schwarz) A. Camus 1935",
       "racemosa Brot. 1804 non Lam. 1785",
       "robur subsp. broteroana auct. pl. non Schwarz 1935",
       "robur var. conimbricensis Camus 1934"
     ]},
    {"flocculenta",
     [
       "flocculenta f. incisa C.H.Mull.1936 flocculenta f. oblongifolia C.H.Mull. 1936 flocculenta var. typica A.Camus 1939"
     ],
     [
       "flocculenta f. incisa C.H.Mull. 1936",
       "flocculenta f. oblongifolia C.H.Mull. 1936",
       "flocculenta var. typica A.Camus 1939"
     ]},
    {"fusiformis",
     [
       "virginiana var. fusiformis (Small) Sarg.1918 virginiana subsp fusiformis (Small) E.Murray 1983 virginiana var. macrophylla Sarg. 1918 oleoides var. quaterna C.H.Muller 1951"
     ],
     [
       "virginiana var. fusiformis (Small) Sarg. 1918",
       "virginiana subsp fusiformis (Small) E.Murray 1983",
       "virginiana var. macrophylla Sarg. 1918",
       "oleoides var. quaterna C.H.Muller 1951"
     ]},
    {"germana",
     [
       "germana var. echinata Trel. 1924 germana subsp subsquarrosa A.Camus 1935 substenocarpa Trel. 1924"
     ],
     [
       "germana var. echinata Trel. 1924",
       "germana subsp subsquarrosa A.Camus 1935",
       "substenocarpa Trel. 1924"
     ]},
    {"hypophaea",
     [
       "Cyclobalanopsis hypophaea (Hayata ) Kudo 1931 Lithocarpus hypophaeus (Hayata) Hayata 1917 Pasania hypophaea (Hayata) Li"
     ],
     [
       "Cyclobalanopsis hypophaea (Hayata) Kudo 1931",
       "Lithocarpus hypophaeus (Hayata) Hayata 1917",
       "Pasania hypophaea (Hayata) Li"
     ]},
    {"laceyi",
     [
       "breviloba f. laceyi (Small) Trel. 1924 breviloba subsp laceyi (Small) A.Camus 1939 glaucoides Auctores not Mart. & Gal. 1843"
     ],
     [
       "breviloba f. laceyi (Small) Trel. 1924",
       "breviloba subsp laceyi (Small) A.Camus 1939",
       "glaucoides Auctores not Mart. & Gal. 1843"
     ]},
    {"liebmannii", ["poculifer Trel. 1924 liebmannii f. brevipes Trel. 1924"],
     ["poculifer Trel. 1924", "liebmannii f. brevipes Trel. 1924"]},
    {"longispica",
     ["Q. semecarpifolia var. longispica Hand.-Mazz. 1929 Q. semecarpifolia Franchet p.p. 1899"],
     ["semecarpifolia var. longispica Hand.-Mazz. 1929", "semecarpifolia Franchet p.p. 1899"]},
    {"minima",
     [
       "virginiana var. minima Sarg.1895 virens var. dentata Chapman 1860 virginiana var. dentata (Chapman) Sarg. 1918 virginiana subsp dentata (Chapm.) E.Murray 1983 virginiana var. pygmaea Sarg. 1918 geminata var. reasoneri (Trel.) A.Camus 1939"
     ],
     [
       "virginiana var. minima Sarg. 1895",
       "virens var. dentata Chapman 1860",
       "virginiana var. dentata (Chapman) Sarg. 1918",
       "virginiana subsp dentata (Chapm.) E.Murray 1983",
       "virginiana var. pygmaea Sarg. 1918",
       "geminata var. reasoneri (Trel.) A.Camus 1939"
     ]},
    {"myrtifolia", ["myrtifolia f. ampla Trel. 1924 phellos var. arenaria Chapm. 1860"],
     ["myrtifolia f. ampla Trel. 1924", "phellos var. arenaria Chapm. 1860"]},
    {"pannosa",
     [
       "ilex var. rufescens Franchet 1899 p.p. semecarpifolia var. rufescens (Franch.) Schottky 1912 aquifolioides var. rufescens (Franch.)W.W.Sm 1924"
     ],
     [
       "ilex var. rufescens Franchet 1899 p.p.",
       "semecarpifolia var. rufescens (Franch.) Schottky 1912",
       "aquifolioides var. rufescens (Franch.) W.W.Sm 1924"
     ]},
    {"pungens",
     ["undulata Torr. var. pungens (Liebm.) Engelm. 1877 undulata var. wrightii Engelm. 1876"],
     ["undulata Torr. var. pungens (Liebm.) Engelm. 1877", "undulata var. wrightii Engelm. 1876"]},
    {"stenophylloides",
     [
       "Cyclobalanopsis stenophylloides (Hayata) Kudo & Masamune 1930 Cyclobalanopsis stenophylla (Bl.) Schottky var. stenophylloides (Hayata)Liao 1974 salicina var stenophylloides (Hayata) S.S.Ying 1988 stenophylla var. stenophylloides (Hayata) A.Camus 1938 salicina var. asiatica Shen in Shen & Liu 1984"
     ],
     [
       "Cyclobalanopsis stenophylloides (Hayata) Kudo & Masamune 1930",
       "Cyclobalanopsis stenophylla (Bl.) Schottky var. stenophylloides (Hayata) Liao 1974",
       "salicina var stenophylloides (Hayata) S.S.Ying 1988",
       "stenophylla var. stenophylloides (Hayata) A.Camus 1938",
       "salicina var. asiatica Shen in Shen & Liu 1984"
     ]},
    {"stewardiana",
     [
       "Cyclobalanopsis stewardiana (A.Camus) Hsu & Wei Jen 1979 Cyclobalanopsis stewardiana var. longicaudata Hsu & al."
     ],
     [
       "Cyclobalanopsis stewardiana (A.Camus) Hsu & Wei Jen 1979",
       "Cyclobalanopsis stewardiana var. longicaudata Hsu & al."
     ]},
    {"tomentella",
     [
       "chrysolepis var. tomentella (Engelm.) E.Murray 1983 chrysolepis subsp tomentella (Engelm.) E.Murray 1983 tomentella var. conjungens Trel. 1924"
     ],
     [
       "chrysolepis var. tomentella (Engelm.) E.Murray 1983",
       "chrysolepis subsp tomentella (Engelm.) E.Murray 1983",
       "tomentella var. conjungens Trel. 1924"
     ]},
    # Hybrids: the leading parentage formula duplicates parent1/parent2.
    {"× alvordiana",
     [
       "douglasii x turbinella or douglasii x john-tuckeri = dumosa var. alvordiana (Eastw.) Jepson 1910"
     ], ["dumosa var. alvordiana (Eastw.) Jepson 1910"]},
    # × shirlingii Bush ex Palmer & Steyerm. 1935 was described as imbricaria ×
    # shumardii var. schneckii; Palmer and ITIS sink it into × egglestonii (1924).
    {"× egglestonii",
     [
       "imbricaria x shumardii x shirlingii Bush ex Palmer & Steyerm. 1935 (as imbricaria X shumardii var . schneckii )"
     ],
     ["× shirlingii Bush ex Palmer & Steyerm. 1935 (as imbricaria × shumardii var. schneckii)"]},
    # WFO also lists × shirlingii under × moultonensis; following Palmer/ITIS,
    # it belongs to × egglestonii only.
    {"× moultonensis", ["shirlingii (x)"], []},
    {"× macdonaldii",
     [
       "pacifica x lobata = dumosa var. macdonaldii (Greene & Kellogg) Jepson 1923 = dumosa subsp macdonaldii (Greene & Kellogg) A.Camus 1935"
     ],
     [
       "dumosa var. macdonaldii (Greene & Kellogg) Jepson 1923",
       "dumosa subsp macdonaldii (Greene & Kellogg) A.Camus 1935"
     ]},
    # Its own publication citation (author already recorded), not a synonym.
    {"× byarsii",
     [
       "macrocarpa x michauxii = Sudworth ex Trel. 1924 Mem. Natl. Acad. Sci. 20: 14. 1924. (as macrocarpa x prinus)"
     ], []},
    {"× cerrioides",
     [
       "lusitanica subsp cerrioides O.Schwarz 1936 sessiliflora var. cerrioides (Willk. et Costa) Willk. 1861 lanuginosa subsp. cerrioides (Willk. & Costa) Nyman 1881 lanuginosa var. cerrioides (Willk. et Costa) A.Camus 1935 lusitanica var. cerrioides (Willk. et Costa) O.Schwarz 1936 lanuginosa (Lam.)Thuil. subsp anselmii (Sennen) Sennen 1931 x anselmii Sennen 1936 lanuginosa var. sennenii A.Camus 1935 x desmotricha O.Schwarz 1936 canariensis X pubescens subsp . subpyrenaica"
     ],
     [
       "lusitanica subsp cerrioides O.Schwarz 1936",
       "sessiliflora var. cerrioides (Willk. et Costa) Willk. 1861",
       "lanuginosa subsp. cerrioides (Willk. & Costa) Nyman 1881",
       "lanuginosa var. cerrioides (Willk. et Costa) A.Camus 1935",
       "lusitanica var. cerrioides (Willk. et Costa) O.Schwarz 1936",
       "lanuginosa (Lam.) Thuil. subsp anselmii (Sennen) Sennen 1931",
       "× anselmii Sennen 1936",
       "lanuginosa var. sennenii A.Camus 1935",
       "× desmotricha O.Schwarz 1936"
     ]},
    {"× duriensis",
     [
       "×coutinhoi f. duriensis Franco & Vasconcellos 1954 [basion.] ×coutinhoi nothosubsp. duriensis (Franco & Vasc.) Monteiro-Henriques & al. 2012 faginea X orocantabrica"
     ],
     [
       "× coutinhoi f. duriensis Franco & Vasconcellos 1954 [basion.]",
       "× coutinhoi nothosubsp. duriensis (Franco & Vasc.) Monteiro-Henriques & al. 2012"
     ]},
    {"× prasina",
     [
       "prasina Bosc ex Endl. 1848 nom. illeg. humilis Lam. var. prasina (Bosc ex Endl.)A.DC 1864 faginea var. prasina (Bosc)Samp. 1910 fruticosa Brot. f. prasina (Bosc ex Pers) O.Schwarz 1938 x angustifolia Villar ex Gonz.Albo (1936: coccifera X faginea"
     ],
     [
       "prasina Bosc ex Endl. 1848 nom. illeg.",
       "humilis Lam. var. prasina (Bosc ex Endl.) A.DC 1864",
       "faginea var. prasina (Bosc) Samp. 1910",
       "fruticosa Brot. f. prasina (Bosc ex Pers) O.Schwarz 1938",
       "× angustifolia Villar ex Gonz.Albo 1936"
     ]},
    {"× tlemcenensis",
     [
       "mirbeckii f. tlemcenensis (A.DC) Trab. 1890 faginea var. tlemcenensis (A.DC) Jahand. & Maire 1932 broteroi (Cout.) Rivas-Martínez & C. Saénz subsp. tlemcenesis (DC.) F.M. Vázquez & A. Coombes (2016: 29) faginea subsp. broteroi (Cout.) var. tlemcenensis (A.DC.) A. Camus (1939: 180) x maroccana (Braun-Blanq. & Maire) Villar (1943: 3) tlemcenensis (A.DC.) Villar f. maroccana (Braun-Blanq. & Maire) Villar (1938: 453) x fagineomirbeckii Villar (1938 450) x jahandiezii A. Camus (1939: 791) x marianica C. Vicioso (1950: 129) x pseudofaginea A.Camus (1939: 792) faginea subsp. tlemcenensis (A.DC.) Maire & Weiller ex Greuter & Burdet 1982 canariensis X faginea"
     ],
     [
       "mirbeckii f. tlemcenensis (A.DC) Trab. 1890",
       "faginea var. tlemcenensis (A.DC) Jahand. & Maire 1932",
       "broteroi (Cout.) Rivas-Martínez & C. Saénz subsp. tlemcenesis (DC.) F.M. Vázquez & A. Coombes (2016: 29)",
       "faginea subsp. broteroi (Cout.) var. tlemcenensis (A.DC.) A. Camus (1939: 180)",
       "× maroccana (Braun-Blanq. & Maire) Villar (1943: 3)",
       "tlemcenensis (A.DC.) Villar f. maroccana (Braun-Blanq. & Maire) Villar (1938: 453)",
       "× fagineomirbeckii Villar (1938: 450)",
       "× jahandiezii A. Camus (1939: 791)",
       "× marianica C. Vicioso (1950: 129)",
       "× pseudofaginea A.Camus (1939: 792)",
       "faginea subsp. tlemcenensis (A.DC.) Maire & Weiller ex Greuter & Burdet 1982"
     ]},
    # Notes split off from the name before them.
    {"cupreata",
     [
       "cupreata f. brachystachys C.H.Muller 1936",
       "nom. illeg. cupreata f. serrata Trel. & C.H.Muller 1936"
     ],
     [
       "cupreata f. brachystachys C.H.Muller 1936 nom. illeg.",
       "cupreata f. serrata Trel. & C.H.Muller 1936"
     ]},
    {"× burnetensis",
     [
       "macrocarpa x virginiana = x coloradensis Ashe 1922",
       "nom. illeg. not Lesquereaux 1888 (f ossil)"
     ], ["× coloradensis Ashe 1922 nom. illeg. not Lesquereaux 1888 (fossil)"]},
    {"× acutidens",
     [
       "cornelius-mulleri X engelmannii (for Nixon & Steele",
       "1980) = dumosa var. acutidens (Torr.) Wenzig 1885 = macdonaldii var. elegantula Greene = dumosa var. elegantula (Greene) Jepson"
     ],
     [
       "dumosa var. acutidens (Torr.) Wenzig 1885",
       "macdonaldii var. elegantula Greene",
       "dumosa var. elegantula (Greene) Jepson"
     ]},
    # Scraper placeholders and journal citations.
    {"potosina",
     [
       "potosina f. exilis Trel. 1924 potosina f. aperta Trel. 1924 jaralensis Trel. 1924 Diagnosis here"
     ],
     ["potosina f. exilis Trel. 1924", "potosina f. aperta Trel. 1924", "jaralensis Trel. 1924"]},
    {"urbani",
     [
       "pennivenia Trel. 1924 Diagnosis here conzattii Trel. 1921 Proc. Amer. Philos. Soc. 60: 33"
     ], ["pennivenia Trel. 1924", "conzattii Trel. 1921"]}
  ]

  # Hybrids whose parentage only appeared in their synonyms. × diegoi's text
  # says "Q. fruticosa Lam. X Q. pyrenaica" but also "inter Quercus lusitanica
  # et Quercus pyrenaica"; fruticosa isn't an accepted name here.
  @parents [
    {"× cerrioides", "canariensis", "pubescens"},
    {"× prasina", "coccifera", "faginea"},
    {"× tlemcenensis", "canariensis", "faginea"},
    {"× diegoi", "lusitanica", "pyrenaica"}
  ]

  @oaks_of_the_world 2

  def up do
    for {species, old, new} <- @splits, do: replace_entries(species, old, new)

    for {species, parent1, parent2} <- @parents do
      repo().query!(
        """
        UPDATE species SET parent1 = ?2, parent2 = ?3
        WHERE scientific_name = ?1 AND COALESCE(parent1, '') = '' AND COALESCE(parent2, '') = ''
          AND EXISTS (SELECT 1 FROM species WHERE scientific_name = ?2)
          AND EXISTS (SELECT 1 FROM species WHERE scientific_name = ?3)
        """,
        [species, parent1, parent2]
      )
    end

    move_diegoi_description()
  end

  def down, do: :ok

  defp replace_entries(species, old, new) do
    with [[id, raw]] <-
           query_rows("SELECT id, synonyms FROM species WHERE scientific_name = ?1", [species]),
         {:ok, list} when is_list(list) <- Jason.decode(raw || "null"),
         {start, count} when count > 0 <- find_run(list, old) do
      updated = Enum.take(list, start) ++ new ++ Enum.drop(list, start + count)
      value = if updated == [], do: nil, else: Jason.encode!(updated)
      repo().query!("UPDATE species SET synonyms = ?1 WHERE id = ?2", [value, id])
    end
  end

  # Index of the first entry of `old` and how many consecutive entries match;
  # {0, 0} unless every entry of `old` is present in order.
  defp find_run(list, old) do
    wanted = Enum.map(old, &collapse/1)
    cleaned = Enum.map(list, &if(is_binary(&1), do: collapse(&1)))

    case Enum.find_index(0..max(length(cleaned) - length(wanted), -1)//1, fn i ->
           Enum.slice(cleaned, i, length(wanted)) == wanted
         end) do
      nil -> {0, 0}
      i -> {i, length(wanted)}
    end
  end

  # × diegoi's Latin diagnosis was split at commas into 13 synonym entries.
  # Rejoin it into its Oaks of the World description and clear the synonyms.
  defp move_diegoi_description do
    with [[id, raw]] <-
           query_rows("SELECT id, synonyms FROM species WHERE scientific_name = '× diegoi'"),
         {:ok, [first | _] = list} <- Jason.decode(raw || "null"),
         true <- collapse(first) =~ "Diagnosis : Arbor mediocris" do
      diagnosis =
        list
        |> Enum.map(&collapse/1)
        |> Enum.join(", ")
        |> String.replace(~r/^.*?Diagnosis : /, "Diagnosis: ")

      %{num_rows: moved} =
        repo().query!(
          """
          UPDATE species_sources
          SET miscellaneous = CASE WHEN COALESCE(miscellaneous, '') = '' THEN ?1
                                   ELSE miscellaneous || char(10) || char(10) || ?1 END
          WHERE species_id = ?2 AND source_id = ?3
          """,
          [diagnosis, id, @oaks_of_the_world]
        )

      # Only drop the synonyms once the text has a new home.
      if moved == 1, do: repo().query!("UPDATE species SET synonyms = NULL WHERE id = ?1", [id])
    end
  end

  defp query_rows(sql, params \\ []), do: repo().query!(sql, params).rows

  defp collapse(text), do: text |> String.split() |> Enum.join(" ")
end
