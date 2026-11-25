defmodule Oaks.Images.Attribution do
  @moduledoc """
  Whether a species photo is properly attributed: it has an importable
  license (`Oaks.Licenses.importable?/1`) and, unless that license is
  Public Domain / CC0, a creator to credit.

  Accepts any map or struct with `:license` and `:creator`, such as an
  `Oaks.Images.Image` or the attrs about to make one.

  Ported from gallformers' `Gallformers.Images.Attribution`, without its
  source-based attribution (species photos have no source record).
  """

  alias Oaks.Licenses

  @public_domain "Public Domain / CC0"

  @doc "Whether `license` requires the creator to be credited."
  @spec requires_attribution?(term()) :: boolean()
  def requires_attribution?(license), do: Licenses.valid?(license) and license != @public_domain

  @doc "Whether `image` has an importable license and, where required, a creator."
  @spec attributed?(map()) :: boolean()
  def attributed?(image) do
    license = Map.get(image, :license)

    Licenses.importable?(license) and
      (not requires_attribution?(license) or present?(Map.get(image, :creator)))
  end

  defp present?(text) when is_binary(text), do: String.trim(text) != ""
  defp present?(_text), do: false
end
