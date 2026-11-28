defmodule Oaks.ImportTest do
  use Oaks.DataCase

  import Oaks.TaxonomyFixtures

  alias Oaks.Import
  alias Oaks.Import.AppliedImport
  alias Oaks.Repo
  alias Oaks.Sources
  alias Oaks.Sources.Source
  alias Oaks.Sources.SpeciesSource
  alias Oaks.Species.Species
  alias Oaks.Taxonomy
  alias Oaks.Taxonomy.Taxon

  # Stands in for the hash of the raw request bytes.
  defp hash(body), do: :crypto.hash(:sha256, :erlang.term_to_binary(body))

  defp dry_run!(body) do
    assert {:ok, report, digest} = Import.dry_run(body, hash(body))
    {report, digest}
  end

  defp apply!(body) do
    {_report, digest} = dry_run!(body)
    assert {:ok, report} = Import.apply(body, hash(body), digest)
    report
  end

  defp errors(body) do
    assert {:error, errors} = Import.dry_run(body, hash(body))
    errors
  end

  defp species!(attrs) do
    {:ok, species} = Oaks.Species.create_species(attrs)
    species
  end

  defp source!(name) do
    {:ok, source} = Sources.create_source(%{source_type: "book", name: name})
    source
  end

  defp cross_table_body do
    %{
      "import_id" => "cross-table",
      "sources" => [
        %{
          "$ref" => "book",
          "source_type" => "book",
          "name" => "Import Test Flora",
          "url" => "https://example.org/flora"
        }
      ],
      "taxa" => [
        %{
          "$ref" => "importsection",
          "name" => "Importsection",
          "level" => "section",
          "parent_id" => %{"$find" => %{"level" => "genus", "name" => "Quercus"}}
        }
      ],
      "species" => [
        %{"$ref" => "imp", "scientific_name" => "importensis", "author" => "Tester 2026"}
      ],
      "species_sources" => [
        %{
          "species_id" => %{"$ref" => "imp"},
          "source_id" => %{"$ref" => "book"},
          "bark" => "Gray and scaly.",
          "local_names" => "import oak, test oak"
        }
      ]
    }
  end

  describe "creating records" do
    test "a dry run reports a record in each table, refs included, and writes nothing" do
      {report, digest} = dry_run!(cross_table_body())

      assert byte_size(digest) == 32

      assert report.summary == %{
               "sources" => %{create: 1, update: 0, unchanged: 0},
               "species" => %{create: 1, update: 0, unchanged: 0},
               "taxa" => %{create: 1, update: 0, unchanged: 0},
               "species_sources" => %{create: 1, update: 0, unchanged: 0}
             }

      assert [source, taxon, species, species_source] = report.records
      assert %{table: "sources", index: 0, ref: "book", action: "create"} = source
      assert source.changes["name"] == "Import Test Flora"
      assert taxon.changes["level"] == "section"
      assert taxon.changes["parent_id"] == Taxonomy.get_genus().id
      assert species.changes == %{"scientific_name" => "importensis", "author" => "Tester 2026"}

      assert species_source.changes["species_id"] == %{"$ref" => "imp"}
      assert species_source.changes["source_id"] == %{"$ref" => "book"}
      assert species_source.changes["local_names"] == ~s(["import oak","test oak"])
      refute Enum.any?(report.records, &Map.has_key?(&1, :id))

      refute Repo.get_by(Species, scientific_name: "importensis")
      refute Repo.get_by(Source, name: "Import Test Flora")
      refute Repo.get_by(Taxon, name: "Importsection")
      refute Repo.get_by(AppliedImport, import_id: "cross-table")
    end

    test "an apply writes every record, links refs and records the import" do
      report = apply!(cross_table_body())

      species = Repo.get_by!(Species, scientific_name: "importensis")
      source = Repo.get_by!(Source, name: "Import Test Flora")

      assert Repo.get_by!(Taxon, name: "Importsection", level: "section").parent_id ==
               Taxonomy.get_genus().id

      species_source = Repo.get_by!(SpeciesSource, species_id: species.id, source_id: source.id)
      assert species_source.bark == "Gray and scaly."

      assert [%{id: source_id}, %{id: taxon_id}, %{id: species_id}, %{id: species_source_id}] =
               report.records

      assert taxon_id == Repo.get_by!(Taxon, name: "Importsection").id

      assert {source_id, species_id, species_source_id} ==
               {source.id, species.id, species_source.id}

      assert %AppliedImport{body_sha256: sha} =
               Repo.get_by(AppliedImport, import_id: "cross-table")

      assert sha == hash(cross_table_body())
    end

    test "a foreign key can be an existing id or a $find" do
      species!(%{scientific_name: "findfk"})
      source = source!("Import FK Source")

      body = %{
        "species_sources" => [
          %{
            "species_id" => %{"$find" => %{"scientific_name" => "findfk"}},
            "source_id" => source.id,
            "leaves" => "Lobed."
          }
        ]
      }

      [record] = apply!(body).records
      species = Repo.get_by!(Species, scientific_name: "findfk")
      assert record.changes["species_id"] == species.id
      assert record.changes["source_id"] == source.id
      assert Repo.get!(SpeciesSource, record.id).leaves == "Lobed."
    end

    test "a foreign key to a missing row is an error" do
      body = %{"species_sources" => [%{"species_id" => 999_999_999, "source_id" => 1}]}

      assert [%{table: "species_sources", index: 0, field: "species_id", message: message}] =
               errors(body)

      assert message == "no species record has id 999999999"
    end
  end

  describe "updating records" do
    test "by id or $find, casting only the given fields; no change is unchanged" do
      section = taxon_fixture(level: "section", parent_id: Taxonomy.get_genus().id)
      by_id = species!(%{scientific_name: "updateone", author: "Old", taxon_id: section.id})
      species!(%{scientific_name: "updatetwo", author: "Same"})

      body = %{
        "species" => [
          %{"id" => by_id.id, "author" => "New"},
          %{"$find" => %{"scientific_name" => "updatetwo"}, "author" => "Same"}
        ]
      }

      report = apply!(body)

      assert report.summary == %{"species" => %{create: 0, update: 1, unchanged: 1}}

      assert [
               %{
                 action: "update",
                 id: id,
                 changes: %{"author" => %{"from" => "Old", "to" => "New"}}
               },
               %{action: "unchanged", changes: changes}
             ] = report.records

      assert id == by_id.id
      assert changes == %{}

      updated = Repo.get!(Species, by_id.id)
      assert updated.author == "New"
      assert updated.taxon_id == section.id
    end

    test "a species_sources row found through its species and source" do
      species = species!(%{scientific_name: "nestedfind"})
      source = source!("Import Nested Source")

      {:ok, row} =
        Sources.create_species_source(%{
          species_id: species.id,
          source_id: source.id,
          bark: "Old"
        })

      body = %{
        "species_sources" => [
          %{
            "$find" => %{
              "species_id" => %{"$find" => %{"scientific_name" => "nestedfind"}},
              "source_id" => source.id
            },
            "bark" => "Furrowed."
          }
        ]
      }

      assert [%{action: "update", id: id}] = apply!(body).records
      assert id == row.id
      assert Repo.get!(SpeciesSource, row.id).bark == "Furrowed."
    end

    test "a $find must match exactly one row" do
      species!(%{scientific_name: "dupone", author: "Twin"})
      species!(%{scientific_name: "duptwo", author: "Twin"})

      body = %{
        "species" => [
          %{"$find" => %{"scientific_name" => "nobodyhere"}, "author" => "X"},
          %{"$find" => %{"author" => "Twin"}, "author" => "Y"}
        ]
      }

      assert [
               %{index: 0, field: "$find", message: "matches no species record"},
               %{index: 1, field: "$find", message: "matches more than one species record" <> _}
             ] = errors(body)
    end

    test "an id with no row is an error" do
      body = %{"species" => [%{"id" => 999_999_999, "author" => "X"}]}

      assert [%{field: "id", message: "no species record has id 999999999"}] = errors(body)
    end

    test "renames are refused" do
      species = species!(%{scientific_name: "norename"})

      {:ok, taxon} =
        Taxonomy.create_taxon(%{
          name: "Norenamesection",
          level: "section",
          parent_id: Taxonomy.get_genus().id
        })

      body = %{
        "species" => [%{"id" => species.id, "scientific_name" => "renamed"}],
        "taxa" => [%{"id" => taxon.id, "name" => "Renamedsection", "level" => "subsection"}]
      }

      assert [
               %{table: "taxa", field: "level"},
               %{table: "taxa", field: "name"},
               %{table: "species", field: "scientific_name", message: message}
             ] = errors(body)

      assert message =~ "rename it in the app"
    end

    test "changing a taxon's content stamps content_updated_at, as the app does" do
      {:ok, taxon} =
        Taxonomy.create_taxon(%{
          name: "Stampsection",
          level: "section",
          parent_id: Taxonomy.get_genus().id,
          content: "Old text."
        })

      body = %{
        "taxa" => [
          %{
            "$find" => %{"name" => "Stampsection", "level" => "section"},
            "content" => "New text."
          }
        ]
      }

      today = Date.to_iso8601(Date.utc_today())
      [record] = apply!(body).records
      assert record.changes["content_updated_at"] == %{"from" => nil, "to" => today}
      assert Repo.get!(Taxon, taxon.id).content_updated_at == today
    end
  end

  describe "the body's shape" do
    test "unknown tables, fields and $ keys are errors, and so is dry_run" do
      body = %{
        "dry_run" => true,
        "articles" => [],
        "species" => [%{"scientific_name" => "shapeone", "colour" => "green", "$upsert" => true}]
      }

      assert [
               %{table: nil, index: nil, field: nil, message: "\"articles\" is not a table" <> _},
               %{table: nil, message: "dry_run doesn't go in the body" <> _},
               %{table: "species", index: 0, field: "$upsert"},
               %{
                 table: "species",
                 index: 0,
                 field: "colour",
                 message: "is not a field of species"
               }
             ] = errors(body)
    end

    test "a table must be a list of objects, and a body must name a table" do
      assert [%{table: "species", index: nil, message: "must be a list of records"}] =
               errors(%{"species" => %{"scientific_name" => "x"}})

      assert [%{table: "species", index: 1, message: "must be an object"}] =
               errors(%{"species" => [%{"scientific_name" => "shapetwo"}, "shapethree"]})

      assert [%{message: "the body names no tables" <> _}] = errors(%{"import_id" => "x"})

      assert [%{message: "the body must be a JSON object" <> _}] = errors(%{"_json" => [1]})
    end

    test "import_id must be a short string" do
      assert [%{field: "import_id"}] =
               errors(%{"import_id" => 7, "species" => [%{"scientific_name" => "shapefour"}]})
    end

    test "list fields take a comma list or a JSON array string" do
      body = %{
        "species" => [
          %{"scientific_name" => "listone", "synonyms" => "×a, ×b"},
          %{"scientific_name" => "listtwo", "synonyms" => ~s([{"name": "old name"}])}
        ]
      }

      apply!(body)
      assert Repo.get_by!(Species, scientific_name: "listone").synonyms == ~s(["×a","×b"])

      assert Repo.get_by!(Species, scientific_name: "listtwo").synonyms ==
               ~s([{"name":"old name"}])
    end
  end

  describe "keys" do
    test "sets a species' taxon and parents by $find" do
      section = taxon_fixture(level: "section", parent_id: Taxonomy.get_genus().id)
      parent1 = species!(%{scientific_name: "keyparentone"})
      parent2 = species!(%{scientific_name: "keyparenttwo"})

      body = %{
        "species" => [
          %{
            "scientific_name" => "× importkey",
            "is_hybrid" => true,
            "taxon_id" => %{"$find" => %{"level" => "section", "name" => section.name}},
            "parent1_id" => %{"$find" => %{"scientific_name" => parent1.scientific_name}},
            "parent2_id" => %{"$find" => %{"scientific_name" => parent2.scientific_name}}
          }
        ]
      }

      apply!(body)

      hybrid = Repo.get_by!(Species, scientific_name: "× importkey")
      assert hybrid.taxon_id == section.id
      assert hybrid.parent1_id == parent1.id
      assert hybrid.parent2_id == parent2.id
    end

    test "a taxon's parent must rank above it" do
      subgenus = taxon_fixture(level: "subgenus")

      body = %{
        "taxa" => [
          %{"name" => "Badparent", "level" => "subgenus", "parent_id" => subgenus.id}
        ]
      }

      assert [%{table: "taxa", index: 0, field: "parent_id", message: message}] =
               errors(body)

      assert message =~ "must rank above subgenus"
    end
  end

  describe "refs" do
    test "a $ref names one record" do
      body = %{
        "species" => [
          %{"$ref" => "same", "scientific_name" => "refone"},
          %{"$ref" => "same", "scientific_name" => "reftwo"}
        ]
      }

      assert [%{index: 1, field: "$ref", message: "same is already the $ref of species record 0"}] =
               errors(body)
    end

    test "a $ref must name a record of the key's table, earlier in the body" do
      source = source!("Import Ref Source")

      body = %{
        "sources" => [%{"$ref" => "src", "source_type" => "book", "name" => "Import Ref Two"}],
        "species_sources" => [
          %{"species_id" => %{"$ref" => "src"}, "source_id" => source.id},
          %{"species_id" => %{"$ref" => "later"}, "source_id" => source.id},
          %{"$ref" => "later", "species_id" => %{"$ref" => "nobody"}, "source_id" => source.id}
        ]
      }

      assert [wrong_table, forward, unknown] = errors(body)
      assert %{index: 0, field: "species_id"} = wrong_table

      assert wrong_table.message ==
               "refers to src, which is sources record 0, not a species record"

      assert %{index: 1, field: "species_id", message: "refers to later, which comes later" <> _} =
               forward

      assert %{index: 2, message: "refers to nobody, which no record in the body defines"} =
               unknown
    end

    test "records that refer to a failed record say so" do
      source = source!("Import Failed Ref Source")

      body = %{
        "species" => [
          %{"$ref" => "bad", "scientific_name" => "failedref", "conservation_status" => "XX"}
        ],
        "species_sources" => [%{"species_id" => %{"$ref" => "bad"}, "source_id" => source.id}]
      }

      assert [
               %{table: "species", index: 0, ref: "bad", field: "conservation_status"},
               %{table: "species_sources", field: "species_id", message: message}
             ] = errors(body)

      assert message == "refers to bad, which has errors"
    end
  end

  describe "errors" do
    test "every record's errors are collected and nothing is written" do
      body = %{
        "sources" => [%{"source_type" => "book"}],
        "species" => [
          %{"scientific_name" => "collectone"},
          %{"scientific_name" => "x", "conservation_status" => "XX"},
          %{"scientific_name" => "collecttwo"}
        ]
      }

      assert {:error, errors} = Import.apply(body, hash(body), :crypto.hash(:sha256, "any"))

      assert [
               %{table: "sources", index: 0, field: "name", message: "can't be blank"},
               %{table: "species", index: 1, field: "conservation_status"},
               %{table: "species", index: 1, field: "scientific_name"}
             ] = errors

      refute Repo.get_by(Species, scientific_name: "collectone")
      refute Repo.get_by(Species, scientific_name: "collecttwo")
    end

    test "a unique collision inside one body is the later record's error" do
      body = %{
        "species" => [%{"scientific_name" => "twiceover"}, %{"scientific_name" => "twiceover"}]
      }

      assert [%{index: 1, field: "scientific_name", message: "has already been taken"}] =
               errors(body)
    end

    test "a second species_sources row for the same pair is an error" do
      species = species!(%{scientific_name: "pairone"})
      source = source!("Import Pair Source")

      row = %{"species_id" => species.id, "source_id" => source.id}
      body = %{"species_sources" => [row, row]}

      assert [%{index: 1, field: "source_id", message: "already has data for this species"}] =
               errors(body)
    end
  end

  describe "the plan" do
    test "an apply whose result would differ from its dry run is refused" do
      species = species!(%{scientific_name: "planchange", author: "First"})
      body = %{"species" => [%{"id" => species.id, "author" => "Mine"}]}

      {_report, digest} = dry_run!(body)
      {:ok, _} = Oaks.Species.update_species(species, %{author: "Someone else"})

      assert Import.apply(body, hash(body), digest) == {:error, :plan_changed}
      assert Repo.get!(Species, species.id).author == "Someone else"
      refute Repo.get_by(AppliedImport, body_sha256: hash(body))
    end

    test "a dry run's digest doesn't depend on the ids new rows get" do
      body = %{"species" => [%{"scientific_name" => "digestone"}]}
      {_report, digest} = dry_run!(body)
      species!(%{scientific_name: "takes-an-id"})
      assert {_report, ^digest} = dry_run!(body)
    end
  end

  describe "the ledger" do
    test "re-sending an applied body changes nothing" do
      body = %{"species" => [%{"scientific_name" => "ledgerone"}]}
      {_report, digest} = dry_run!(body)
      assert {:ok, _} = Import.apply(body, hash(body), digest)

      assert {:already_applied, %AppliedImport{import_id: nil}} = Import.dry_run(body, hash(body))
      assert {:already_applied, %AppliedImport{}} = Import.apply(body, hash(body), digest)

      assert Repo.aggregate(from(s in Species, where: s.scientific_name == "ledgerone"), :count) ==
               1
    end

    test "an applied import_id with another body is a conflict" do
      apply!(%{"import_id" => "batch-1", "species" => [%{"scientific_name" => "ledgertwo"}]})

      other = %{"import_id" => "batch-1", "species" => [%{"scientific_name" => "ledgerthree"}]}
      assert Import.dry_run(other, hash(other)) == {:error, :import_id_conflict}
      assert Import.apply(other, hash(other), <<0::256>>) == {:error, :import_id_conflict}
      refute Repo.get_by(Species, scientific_name: "ledgerthree")
    end
  end
end
