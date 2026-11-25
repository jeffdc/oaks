defmodule Oaks.Storage.Local do
  @moduledoc """
  Stores species photos on the local disk, for dev (and for tests of real
  image files), with no AWS credentials.

  Files go under the `:local_root` of `config :oaks, :images` (`tmp/images`
  in dev), which the dev endpoint serves at `/dev-images` (the dev
  `:cdn_url`). There is no CDN, so an invalidation completes at once, and no
  version history: a deleted file is gone.
  """

  @behaviour Oaks.Storage.Adapter

  alias Oaks.Storage.Images

  @impl true
  def put(path, data, _content_type) do
    file = file(path)
    # Write beside the file, then rename, so a reader or a crash never sees
    # half a file.
    partial = "#{file}.#{System.unique_integer([:positive])}.partial"

    with :ok <- File.mkdir_p(Path.dirname(file)),
         :ok <- File.write(partial, data),
         :ok <- File.rename(partial, file) do
      :ok
    else
      {:error, reason} ->
        File.rm(partial)
        {:error, reason}
    end
  end

  @impl true
  def delete(path) do
    case File.rm(file(path)) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def list(prefix) do
    root = root()

    paths =
      root
      |> Path.join("**")
      |> Path.wildcard(match_dot: true)
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(&Path.relative_to(&1, root))
      |> Enum.filter(&String.starts_with?(&1, prefix))
      |> Enum.reject(&String.ends_with?(&1, ".partial"))
      |> Enum.sort()

    {:ok, paths}
  end

  @impl true
  def create_invalidation(_paths, caller_reference), do: {:ok, "local-" <> caller_reference}

  @impl true
  def invalidation_status(_invalidation_id), do: {:ok, :completed}

  @doc "The directory files are stored in (`Plug.Static` serves it in dev)."
  @spec root() :: String.t()
  def root, do: Images.config(:local_root)

  defp file(path), do: Path.join(root(), path)
end
