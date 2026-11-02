defmodule OaksWeb.SpeciesNameTest do
  use ExUnit.Case

  alias OaksWeb.SpeciesName

  doctest OaksWeb.SpeciesName

  test "named hybrids get one hybrid sign regardless of stored spacing" do
    for name <- ["× raineri", "×raineri", " ×  raineri"] do
      assert SpeciesName.full_name(name, true) == "Quercus × raineri"
    end
  end

  test "formula hybrids keep their own sign and get no leading one" do
    assert SpeciesName.full_name("agrifolia × parvula", true) == "Quercus agrifolia × parvula"
    assert SpeciesName.full_name("dumosa x engelmannii", true) == "Quercus dumosa x engelmannii"
  end

  test "flagged hybrids without a stored sign still show one" do
    assert SpeciesName.full_name("bebbiana", true) == "Quercus × bebbiana"
    assert SpeciesName.full_name("alba", false) == "Quercus alba"
  end
end
