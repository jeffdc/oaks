defmodule Oaks.Storage.Variants do
  @moduledoc """
  Resizes a photo's original into its size variants
  (`Oaks.Storage.Images.variant_sizes/0`), with libvips (`Image`).

  It only turns bytes into bytes. The import worker stores the original and
  the variants, and publishes the photo once all five are stored.

  Adapted from gallformers' `generate_size_variants/2`, which re-downloaded
  the original from the CDN and resized in fire-and-forget tasks, so nothing
  knew when, or whether, the variants existed.
  """

  alias Oaks.Storage.Images

  # Over this many pixels the original is refused before decoding, so a small
  # file that claims huge dimensions can't exhaust memory. iNaturalist's
  # originals are at most 2048 px on the long edge.
  @max_pixels 100_000_000

  @formats %{"jpg" => ".jpg", "jpeg" => ".jpg", "png" => ".png", "webp" => ".webp"}

  @doc """
  Every variant of `original`, an image file of type `extension` (`jpg`,
  `jpeg`, `png` or `webp`), smallest first.

  Each variant has the original's format, its longest edge is the variant's
  size (never enlarged: a smaller original keeps its own size), it is turned
  upright from the original's orientation tag, and its metadata is removed.
  Returns an error unless every variant was made.
  """
  @spec generate(binary(), String.t()) ::
          {:ok, [{Images.size(), binary()}]} | {:error, term()}
  def generate(original, extension) when is_binary(original) and is_binary(extension) do
    ext = extension |> String.trim_leading(".") |> String.downcase()

    with {:ok, suffix} <- suffix(ext),
         {:ok, image} <- open(original) do
      resize_all(image, suffix, Images.variant_sizes(), [])
    end
  end

  defp resize_all(_image, _suffix, [], variants), do: {:ok, Enum.reverse(variants)}

  defp resize_all(image, suffix, [{size, length} | rest], variants) do
    case resize(image, length, suffix) do
      {:ok, data} -> resize_all(image, suffix, rest, [{size, data} | variants])
      {:error, reason} -> {:error, {:resize_failed, size, reason}}
    end
  end

  defp suffix(ext) do
    case Map.fetch(@formats, ext) do
      {:ok, suffix} -> {:ok, suffix}
      :error -> {:error, {:unsupported_extension, ext}}
    end
  end

  defp open(original) do
    with {:ok, image} <- Image.from_binary(original) do
      if Image.width(image) * Image.height(image) > @max_pixels,
        do: {:error, :too_many_pixels},
        else: {:ok, image}
    end
  end

  defp resize(image, length, suffix) do
    with {:ok, resized} <- Image.thumbnail(image, length, resize: :down, autorotate: true) do
      Image.write(resized, :memory, suffix: suffix, strip_metadata: true, quality: 85)
    end
  end
end
