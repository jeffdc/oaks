defmodule Oaks.Storage.Images do
  @moduledoc """
  Where species photos are stored and how they are addressed: object paths,
  public URLs, and the configured store (`Oaks.Storage.Adapter`).

  Each import attempt stores five files under paths unique to that attempt:
  the original, `species/{id}/{id}_{ts}_{uniq}_original.{ext}`, and one file
  per size variant with `original` replaced by the size name. A path is never
  written twice, so the CDN can cache it for good; removing a photo deletes
  its files and then invalidates their paths (`invalidate/2`).

  The species ID in a path records where a photo was first imported. It is
  not the photo's owner: merging species moves photos without moving files.

  Configured by `config :oaks, :images` (config/*.exs, config/runtime.exs).
  Ported from gallformers' `Gallformers.Storage.Images`.
  """

  alias Oaks.Storage.Adapter

  @variant_sizes [small: 300, medium: 800, large: 1200, xlarge: 2000]
  @sizes [:original | Keyword.keys(@variant_sizes)]

  @content_types %{
    "jpg" => "image/jpeg",
    "jpeg" => "image/jpeg",
    "png" => "image/png",
    "webp" => "image/webp"
  }

  @typedoc "A stored file of a photo: the original or one of its variants."
  @type size :: :original | :small | :medium | :large | :xlarge

  @doc "The variant sizes and their longest edge in pixels, smallest first."
  @spec variant_sizes() :: [{size(), pos_integer()}]
  def variant_sizes, do: @variant_sizes

  @doc "Every stored size of a photo, the original first."
  @spec sizes() :: [size()]
  def sizes, do: @sizes

  @doc """
  Whether photos of file type `extension` (with or without a leading dot,
  any case) can be stored: `jpg`, `jpeg`, `png` or `webp`.
  """
  @spec supported_extension?(String.t()) :: boolean()
  def supported_extension?(extension) when is_binary(extension),
    do: Map.has_key?(@content_types, normalize_extension(extension))

  @doc """
  A new, unique path for the original of a photo imported to the species.

  `extension` is the original's file type (`jpg`, `jpeg`, `png` or `webp`,
  with or without a leading dot, any case); it is stored lower case.
  """
  @spec original_path(pos_integer(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def original_path(species_id, extension) when is_integer(species_id) and species_id > 0 do
    ext = normalize_extension(extension)

    if Map.has_key?(@content_types, ext) do
      timestamp = System.system_time(:millisecond)
      # Random rather than System.unique_integer/1, which restarts with the VM.
      unique = Base.encode16(:crypto.strong_rand_bytes(5), case: :lower)
      {:ok, "species/#{species_id}/#{species_id}_#{timestamp}_#{unique}_original.#{ext}"}
    else
      {:error, {:unsupported_extension, extension}}
    end
  end

  defp normalize_extension(extension),
    do: extension |> String.trim_leading(".") |> String.downcase()

  @doc """
  The path of one size of a photo, from its original's path.

      iex> Oaks.Storage.Images.variant_path("species/3/3_1_ab_original.jpg", :small)
      "species/3/3_1_ab_small.jpg"
  """
  @spec variant_path(String.t(), size()) :: String.t()
  def variant_path(original_path, :original), do: original_path

  def variant_path(original_path, size) when size in @sizes do
    ext = Path.extname(original_path)
    base = Path.rootname(original_path)

    case String.split_at(base, -String.length("_original")) do
      {stem, "_original"} -> "#{stem}_#{size}#{ext}"
      _ -> raise ArgumentError, "not an original's path: #{inspect(original_path)}"
    end
  end

  @doc "The paths of every stored size of a photo, the original first."
  @spec all_paths(String.t()) :: [String.t()]
  def all_paths(original_path), do: Enum.map(@sizes, &variant_path(original_path, &1))

  @doc "The content type stored with a path, from its extension."
  @spec content_type(String.t()) :: String.t()
  def content_type(path) do
    ext = path |> Path.extname() |> String.trim_leading(".") |> String.downcase()
    Map.get(@content_types, ext, "application/octet-stream")
  end

  @doc "The public URL a stored file is served from."
  @spec public_url(String.t()) :: String.t()
  def public_url(path) when is_binary(path) do
    "#{config(:cdn_url)}/#{String.trim_leading(path, "/")}"
  end

  @doc "The public URL of one size of a photo, from its original's path."
  @spec variant_url(String.t(), size()) :: String.t()
  def variant_url(original_path, size), do: original_path |> variant_path(size) |> public_url()

  @doc "Stores `data` at `path` with `content_type` (see `content_type/1`)."
  @spec put(String.t(), binary(), String.t()) :: :ok | {:error, term()}
  def put(path, data, content_type) when is_binary(data) and is_binary(content_type) do
    with :ok <- check_path(path), do: adapter().put(path, data, content_type)
  end

  @doc """
  Deletes a stored file, or each of a list of them, stopping at the first
  failure. Missing files are not an error, so a partial delete can be repeated.
  """
  @spec delete(String.t() | [String.t()]) :: :ok | {:error, term()}
  def delete(paths) when is_list(paths) do
    with :ok <- check_paths(paths), do: delete_each(paths)
  end

  def delete(path) when is_binary(path), do: delete([path])

  defp delete_each([]), do: :ok

  defp delete_each([path | rest]) do
    case adapter().delete(path) do
      :ok -> delete_each(rest)
      {:error, reason} -> {:error, {path, reason}}
    end
  end

  @doc "Lists the stored paths that start with `prefix` (for example `species/12/`)."
  @spec list(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def list(prefix) when is_binary(prefix) do
    with :ok <- check_prefix(prefix), do: adapter().list(prefix)
  end

  @doc """
  Asks the CDN to stop serving cached copies of `paths`, and returns the
  invalidation's ID for `invalidation_status/1`.

  Give a `caller_reference` that is stable for this removal, such as the
  cleanup record's ID: if the app stops after asking but before saving the
  ID, asking again with the same reference and paths returns the same
  invalidation.
  """
  @spec invalidate([String.t()], String.t()) ::
          {:ok, Adapter.invalidation_id()} | {:error, term()}
  def invalidate([_ | _] = paths, caller_reference)
      when is_binary(caller_reference) and caller_reference != "" do
    with :ok <- check_paths(paths), do: adapter().create_invalidation(paths, caller_reference)
  end

  @doc "Whether an invalidation from `invalidate/2` has completed."
  @spec invalidation_status(Adapter.invalidation_id()) ::
          {:ok, :in_progress | :completed} | {:error, term()}
  def invalidation_status(invalidation_id) when is_binary(invalidation_id) do
    adapter().invalidation_status(invalidation_id)
  end

  @doc false
  @spec config(atom()) :: term()
  def config(key), do: Application.fetch_env!(:oaks, :images) |> Keyword.get(key)

  defp adapter, do: config(:adapter)

  # Object keys: relative, segments of letters, digits, `.`, `_` and `-`, no
  # `.` or `..` segments. Local maps keys onto the file system, so this is
  # what keeps a key inside its root.
  @segment ~r/\A[A-Za-z0-9._-]+\z/

  defp check_paths(paths) do
    Enum.find_value(paths, :ok, fn path ->
      case check_path(path) do
        :ok -> nil
        error -> error
      end
    end)
  end

  defp check_path(path) when is_binary(path) do
    segments = String.split(path, "/")
    if Enum.all?(segments, &valid_segment?/1), do: :ok, else: {:error, {:invalid_path, path}}
  end

  defp check_path(path), do: {:error, {:invalid_path, path}}

  # A prefix may be empty or end in "/" (a folder).
  defp check_prefix(""), do: :ok

  defp check_prefix(prefix) do
    case check_path(String.trim_trailing(prefix, "/")) do
      :ok -> :ok
      {:error, _} -> {:error, {:invalid_path, prefix}}
    end
  end

  defp valid_segment?(segment),
    do: segment not in [".", ".."] and Regex.match?(@segment, segment)
end
