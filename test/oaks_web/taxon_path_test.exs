defmodule OaksWeb.TaxonPathTest do
  use Oaks.DataCase

  alias OaksWeb.TaxonPath

  doctest OaksWeb.TaxonPath

  test "links each taxon to its taxonomy page and a variety's species to its species page" do
    placement = [
      %{level: "subgenus", name: "Cerris", hybrid: false},
      %{level: "section", name: "Cerris", hybrid: false},
      %{level: "species", name: "acutissima", hybrid: false}
    ]

    assert Enum.map(TaxonPath.ranks(placement), & &1.path) ==
             ["/taxonomy", "/taxonomy/Cerris", "/taxonomy/Cerris/Cerris", "/species/acutissima"]
  end

  test "skips a missing rank in the path, as the taxonomy pages do" do
    placement = [
      %{level: "subgenus", name: "Quercus", hybrid: false},
      %{level: "section", name: "Quercus", hybrid: false},
      %{level: "complex", name: "dumosa", hybrid: false}
    ]

    assert List.last(TaxonPath.ranks(placement)).path == "/taxonomy/Quercus/Quercus/dumosa"
  end

  test "makes a species record the current step, with its hybrid flag" do
    assert TaxonPath.current(%{scientific_name: "× bebbiana", is_hybrid: true}) ==
             %{level: "species", name: "× bebbiana", hybrid: true}

    assert TaxonPath.current(%{scientific_name: "alba", is_hybrid: nil}).hybrid == false
  end
end
