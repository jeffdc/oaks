defmodule Oaks.ChangesetHelpersTest do
  use ExUnit.Case, async: true

  import Oaks.ChangesetHelpers

  alias Ecto.Changeset
  alias Oaks.Articles.Article
  alias Oaks.Sources.{Source, SpeciesSource}
  alias Oaks.Species.Species
  alias Oaks.Taxonomy.Taxon

  @url_message "must be a valid URL starting with http:// or https://"

  defmodule TestSchema do
    use Ecto.Schema

    schema "test" do
      field :name, :string
      field :url, :string
      field :nickname, :string, virtual: true
      field :count, :integer
      field :tags, {:array, :string}
    end
  end

  defp cast_name(attrs, data \\ %TestSchema{}) do
    Changeset.cast(data, attrs, [:name, :url])
  end

  defp cast_url(attrs, data \\ %TestSchema{}) do
    Changeset.cast(data, attrs, [:url])
  end

  describe "trim_strings/1" do
    test "trims leading whitespace" do
      cs = cast_name(%{name: "  Quercus alba"}) |> trim_strings()
      assert Changeset.get_change(cs, :name) == "Quercus alba"
    end

    test "trims trailing whitespace" do
      cs = cast_name(%{name: "Quercus alba \n\t"}) |> trim_strings()
      assert Changeset.get_change(cs, :name) == "Quercus alba"
    end

    test "trims every changed string field" do
      cs = cast_name(%{name: " Quercus alba ", url: " https://example.com "}) |> trim_strings()
      assert cs.changes == %{name: "Quercus alba", url: "https://example.com"}
    end

    test "preserves inner whitespace" do
      cs = cast_name(%{name: " Quercus  alba "}) |> trim_strings()
      assert Changeset.get_change(cs, :name) == "Quercus  alba"
    end

    test "leaves clean strings alone" do
      cs = cast_name(%{name: "Quercus alba"}) |> trim_strings()
      assert Changeset.get_change(cs, :name) == "Quercus alba"
    end

    test "handles nil without error" do
      cs = cast_name(%{name: nil}, %TestSchema{name: "Quercus alba"}) |> trim_strings()
      assert Changeset.fetch_change(cs, :name) == {:ok, nil}
    end

    test "drops a change that trims to the stored value" do
      cs =
        cast_name(%{name: "  Quercus alba "}, %TestSchema{name: "Quercus alba"}) |> trim_strings()

      assert cs.changes == %{}
    end

    test "leaves virtual, integer and array fields alone" do
      cs =
        %TestSchema{}
        |> Changeset.change(%{nickname: " white oak ", count: 5, tags: [" alba "]})
        |> trim_strings()

      assert cs.changes == %{nickname: " white oak ", count: 5, tags: [" alba "]}
    end
  end

  describe "validate_url/2" do
    test "accepts an http URL" do
      cs = cast_url(%{url: "http://example.com"}) |> validate_url(:url)
      assert cs.valid?
    end

    test "accepts an https URL with a path and query" do
      cs = cast_url(%{url: "https://example.com/path?q=1"}) |> validate_url(:url)
      assert cs.valid?
    end

    test "accepts an empty string" do
      cs = cast_url(%{url: ""}) |> validate_url(:url)
      assert cs.valid?
    end

    test "accepts no change" do
      cs = cast_url(%{}) |> validate_url(:url)
      assert cs.valid?
    end

    test "rejects a URL without a scheme" do
      cs = cast_url(%{url: "doi.org/10.1234"}) |> validate_url(:url)
      refute cs.valid?
      assert {@url_message, _} = cs.errors[:url]
    end

    test "rejects plain text" do
      cs = cast_url(%{url: "some random text"}) |> validate_url(:url)
      refute cs.valid?
    end

    test "rejects the literal none" do
      cs = cast_url(%{url: "none"}) |> validate_url(:url)
      refute cs.valid?
    end

    test "rejects an ftp URL" do
      cs = cast_url(%{url: "ftp://example.com/file"}) |> validate_url(:url)
      refute cs.valid?
    end

    test "rejects a javascript URL" do
      cs = cast_url(%{url: "javascript:alert(1)"}) |> validate_url(:url)
      refute cs.valid?
    end

    test "puts https:// in front of a www. value" do
      cs = cast_url(%{url: "www.example.com/page"}) |> validate_url(:url)
      assert cs.valid?
      assert Changeset.get_change(cs, :url) == "https://www.example.com/page"
    end

    test "trims whitespace" do
      cs = cast_url(%{url: "  https://example.com  "}) |> validate_url(:url)
      assert cs.valid?
      assert Changeset.get_change(cs, :url) == "https://example.com"
    end

    test "treats a whitespace-only value as empty" do
      cs = cast_url(%{url: "   "}) |> validate_url(:url)
      assert cs.valid?
      assert Changeset.get_field(cs, :url) in [nil, ""]
    end

    test "treats a whitespace-only put_change as empty" do
      cs = %TestSchema{} |> Changeset.change(%{url: "   "}) |> validate_url(:url)
      assert cs.valid?
      assert Changeset.get_change(cs, :url) == ""
    end

    test "doesn't check an unchanged stored value" do
      cs = cast_name(%{name: "Quercus alba"}, %TestSchema{url: "none"}) |> validate_url(:url)
      assert cs.valid?
    end
  end

  describe "empty_strings_to_nil/2" do
    test "turns an empty-string change into nil" do
      cs =
        %TestSchema{name: "Quercus alba"}
        |> Changeset.change(%{name: ""})
        |> empty_strings_to_nil([:name])

      assert Changeset.fetch_change(cs, :name) == {:ok, nil}
    end

    test "drops the change when the stored value is already nil" do
      cs = %TestSchema{} |> Changeset.change(%{name: ""}) |> empty_strings_to_nil([:name])
      assert cs.changes == %{}
    end

    test "leaves non-empty values and unlisted fields alone" do
      cs =
        %TestSchema{}
        |> Changeset.change(%{name: "Quercus alba", url: ""})
        |> empty_strings_to_nil([:name])

      assert cs.changes == %{name: "Quercus alba", url: ""}
    end
  end

  describe "schema changesets" do
    test "Species trims the scientific name" do
      cs = Species.changeset(%Species{}, %{scientific_name: "  Quercus alba ", is_hybrid: false})
      assert cs.valid?
      assert Changeset.get_change(cs, :scientific_name) == "Quercus alba"
    end

    test "Source rejects a bad url and license_url" do
      cs =
        Source.changeset(%Source{}, %{
          source_type: "website",
          name: "Example",
          url: "example.com",
          license_url: "CC BY 4.0"
        })

      refute cs.valid?
      assert {@url_message, _} = cs.errors[:url]
      assert {@url_message, _} = cs.errors[:license_url]
    end

    test "Source saves a www. url as https" do
      cs =
        Source.changeset(%Source{}, %{
          source_type: "website",
          name: "Example",
          url: " www.example.com "
        })

      assert cs.valid?
      assert Changeset.get_change(cs, :url) == "https://www.example.com"
    end

    test "Source doesn't check a url it isn't changing" do
      source = %Source{source_type: "website", name: "Example", url: "legacy text"}
      cs = Source.changeset(source, %{name: "Renamed"})
      assert cs.valid?
    end

    test "SpeciesSource rejects a bad url and still normalizes local names" do
      cs =
        SpeciesSource.changeset(%SpeciesSource{}, %{
          species_id: 1,
          source_id: 1,
          url: "not a url",
          local_names: "  white oak , stave oak  "
        })

      refute cs.valid?
      assert {@url_message, _} = cs.errors[:url]
      assert Changeset.get_change(cs, :local_names) == ~s(["white oak","stave oak"])
    end

    test "Article form_changeset trims the title" do
      cs = Article.form_changeset(%Article{}, %{title: " Oak galls ", author: "Jeff"})
      assert cs.valid?
      assert Changeset.get_change(cs, :title) == "Oak galls"
    end

    test "Article changeset trims the title" do
      cs =
        Article.changeset(%Article{}, %{
          slug: "oak-galls",
          title: "Oak galls  ",
          author: "Jeff",
          created_at: "2026-11-21",
          updated_at: "2026-11-21"
        })

      assert cs.valid?
      assert Changeset.get_change(cs, :title) == "Oak galls"
    end

    test "Taxon trims the name" do
      cs = Taxon.changeset(%Taxon{}, %{name: " Lobatae ", level: "section"})
      assert cs.valid?
      assert Changeset.get_change(cs, :name) == "Lobatae"
    end
  end
end
