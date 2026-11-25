defmodule Oaks.Licenses do
  @moduledoc """
  The licenses a species photo can carry, with their canonical URLs.

  A photo with an open license (`importable?/1`) can be imported as it is.
  An All Rights Reserved one, which is also what an unknown license maps to
  (`Oaks.INaturalist.map_license/1`), can be imported only with an editor's
  recorded confirmation that its creator has given permission
  (`needs_permission?/1`; Jeff, 2026-11-25).

  Ported from gallformers' `Gallformers.Licenses`.
  """

  @all_rights_reserved "All Rights Reserved"

  # In display order, each with its canonical URL (nil when it has none).
  @licenses [
    {"Public Domain / CC0", "https://creativecommons.org/publicdomain/zero/1.0/"},
    {"CC-BY", "https://creativecommons.org/licenses/by/4.0/"},
    {"CC-BY-SA", "https://creativecommons.org/licenses/by-sa/4.0/"},
    {"CC-BY-NC", "https://creativecommons.org/licenses/by-nc/4.0/"},
    {"CC-BY-NC-SA", "https://creativecommons.org/licenses/by-nc-sa/4.0/"},
    {"CC-BY-ND", "https://creativecommons.org/licenses/by-nd/4.0/"},
    {"CC-BY-NC-ND", "https://creativecommons.org/licenses/by-nc-nd/4.0/"},
    {@all_rights_reserved, nil}
  ]

  @urls Map.new(@licenses)

  @doc "Every license, in display order."
  @spec all() :: [String.t()]
  def all, do: Enum.map(@licenses, &elem(&1, 0))

  @doc "The All Rights Reserved license."
  @spec all_rights_reserved() :: String.t()
  def all_rights_reserved, do: @all_rights_reserved

  @doc "Whether `license` is one of `all/0`."
  @spec valid?(term()) :: boolean()
  def valid?(license), do: is_binary(license) and Map.has_key?(@urls, license)

  @doc """
  Whether a photo with `license` may be imported without the creator's
  permission: a valid license other than All Rights Reserved.
  """
  @spec importable?(term()) :: boolean()
  def importable?(license), do: valid?(license) and license != @all_rights_reserved

  @doc """
  Whether a photo with `license` may be imported only with the creator's
  permission: All Rights Reserved.
  """
  @spec needs_permission?(term()) :: boolean()
  def needs_permission?(license), do: license == @all_rights_reserved

  @doc """
  The canonical URL of `license`, or nil when it has none.

      iex> Oaks.Licenses.url("CC-BY")
      "https://creativecommons.org/licenses/by/4.0/"

      iex> Oaks.Licenses.url("All Rights Reserved")
      nil
  """
  @spec url(term()) :: String.t() | nil
  def url(license) when is_binary(license), do: Map.get(@urls, license)
  def url(_license), do: nil
end
