defmodule Oaks.Storage.Adapter do
  @moduledoc """
  The contract a species photo store implements (`Oaks.Storage.S3` in
  production, `Oaks.Storage.Local` in dev, a Mox mock in tests). Callers use
  `Oaks.Storage.Images`, which picks the configured adapter.

  Paths are object keys relative to the store's root, such as
  `species/12/12_1764000000000_9f2c4a1b07_original.jpg`; `Oaks.Storage.Images`
  has already checked them.

  Every operation is safe to repeat: putting a path again replaces it,
  deleting a missing path succeeds, and creating an invalidation again with
  the same caller reference and paths returns the same invalidation.
  """

  @typedoc "An object key relative to the store's root."
  @type path :: String.t()

  @typedoc "The store's ID for a cache invalidation, kept so a restart can check it."
  @type invalidation_id :: String.t()

  @doc "Stores `data` at `path` with the given content type."
  @callback put(path(), data :: binary(), content_type :: String.t()) :: :ok | {:error, term()}

  @doc "Deletes the object at `path`. A missing object is not an error."
  @callback delete(path()) :: :ok | {:error, term()}

  @doc "Lists the paths that start with `prefix`, in key order."
  @callback list(prefix :: String.t()) :: {:ok, [path()]} | {:error, term()}

  @doc """
  Asks the CDN to stop serving cached copies of `paths`. `caller_reference`
  identifies the request: repeating it with the same paths returns the
  invalidation the first call made instead of a second one.
  """
  @callback create_invalidation([path()], caller_reference :: String.t()) ::
              {:ok, invalidation_id()} | {:error, term()}

  @doc "Whether the invalidation has completed."
  @callback invalidation_status(invalidation_id()) ::
              {:ok, :in_progress | :completed} | {:error, term()}
end
