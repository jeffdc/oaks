defmodule OaksWeb.SpeciesName do
  @moduledoc """
  Display formatting for species names, including hybrid notation.

  Named hybrids are stored with a leading hybrid sign (`"× raineri"` or
  `"×bebbiana"`) and display as `Quercus × raineri`. Formula hybrids are
  stored as `"agrifolia × parvula"` and already carry their sign, so they
  display as `Quercus agrifolia × parvula` with no leading ×.
  """

  @doc """
  Returns the name without a leading hybrid sign.

      iex> OaksWeb.SpeciesName.epithet("× raineri")
      "raineri"

      iex> OaksWeb.SpeciesName.epithet("alba")
      "alba"
  """
  @spec epithet(String.t()) :: String.t()
  def epithet(name), do: String.replace(name, ~r/^\s*×\s*/u, "")

  @doc """
  True when a hybrid sign should be shown before the epithet.

      iex> OaksWeb.SpeciesName.hybrid_sign?("× raineri", true)
      true

      iex> OaksWeb.SpeciesName.hybrid_sign?("agrifolia × parvula", true)
      false

      iex> OaksWeb.SpeciesName.hybrid_sign?("alba", false)
      false
  """
  @spec hybrid_sign?(String.t(), boolean() | nil) :: boolean()
  def hybrid_sign?(name, is_hybrid) do
    String.starts_with?(String.trim_leading(name), "×") or
      (is_hybrid == true and not formula?(name))
  end

  @doc """
  Returns the name with normalized hybrid notation, without the genus.

      iex> OaksWeb.SpeciesName.label("×bebbiana", true)
      "× bebbiana"

      iex> OaksWeb.SpeciesName.label("agrifolia × parvula", true)
      "agrifolia × parvula"
  """
  @spec label(String.t(), boolean() | nil) :: String.t()
  def label(name, is_hybrid) do
    if hybrid_sign?(name, is_hybrid), do: "× " <> epithet(name), else: epithet(name)
  end

  @doc """
  Returns the full name including the genus.

      iex> OaksWeb.SpeciesName.full_name("× raineri", true)
      "Quercus × raineri"
  """
  @spec full_name(String.t(), boolean() | nil) :: String.t()
  def full_name(name, is_hybrid), do: "Quercus " <> label(name, is_hybrid)

  @doc """
  Returns a taxon's name as plain text, for titles and labels. A complex
  is named for its species, so it takes the abbreviated genus.

      iex> OaksWeb.SpeciesName.taxon_label("complex", "coccinea")
      "Q. coccinea"

      iex> OaksWeb.SpeciesName.taxon_label("section", "Lobatae")
      "Lobatae"
  """
  @spec taxon_label(String.t() | nil, String.t()) :: String.t()
  def taxon_label("complex", name), do: "Q. " <> name
  def taxon_label(_level, name), do: name

  defp formula?(name), do: epithet(name) =~ ~r/\s[×x]\s/u
end
