defmodule Oaks.Images.Attribution do
  @moduledoc """
  Whether a species photo is properly attributed, and how its license reads
  in its credit.

  A photo is attributed when it has a valid license, a creator to credit
  unless that license is Public Domain / CC0, and, when it is All Rights
  Reserved, the recorded confirmation that its creator gave permission
  (`permission_confirmed_by`).

  Accepts any map or struct with `:license`, `:creator` and
  `:permission_confirmed_by`, such as an `Oaks.Images.Image` or the attrs
  about to make one.

  Ported from gallformers' `Gallformers.Images.Attribution`, without its
  source-based attribution (species photos have no source record).
  """

  alias Oaks.Licenses

  @public_domain "Public Domain / CC0"

  @doc "Whether `license` requires the creator to be credited."
  @spec requires_attribution?(term()) :: boolean()
  def requires_attribution?(license), do: Licenses.valid?(license) and license != @public_domain

  @doc """
  Whether `image` has a license it may be shown under (an open one, or All
  Rights Reserved with the creator's permission recorded) and, where
  required, a creator.
  """
  @spec attributed?(map()) :: boolean()
  def attributed?(image) do
    license = Map.get(image, :license)

    licensed? =
      Licenses.importable?(license) or
        (Licenses.needs_permission?(license) and
           present?(Map.get(image, :permission_confirmed_by)))

    licensed? and (not requires_attribution?(license) or present?(Map.get(image, :creator)))
  end

  @doc """
  The license as a photo's credit names it: the license's name, or for an
  All Rights Reserved photo, that it is used with the creator's permission.

      iex> Oaks.Images.Attribution.license_label(%{license: "CC-BY-NC"})
      "CC-BY-NC"

      iex> Oaks.Images.Attribution.license_label(%{license: "All Rights Reserved"})
      "All rights reserved, used with the creator's permission"
  """
  @spec license_label(map()) :: String.t() | nil
  def license_label(image) do
    case Map.get(image, :license) do
      license when is_binary(license) ->
        if Licenses.needs_permission?(license),
          do: "All rights reserved, used with the creator's permission",
          else: license

      _ ->
        nil
    end
  end

  defp present?(text) when is_binary(text), do: String.trim(text) != ""
  defp present?(_text), do: false
end
