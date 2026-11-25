defmodule Oaks.Images.ImportWorker do
  @moduledoc """
  Stores an import attempt's files and publishes its photo
  (`Oaks.Images.ImportAttempt`).

  A run claims the attempt (a lease no other run or cleanup will cross),
  downloads the photo from iNaturalist, makes its four variants, and stores
  the original and the variants. Before each write it checks that it still
  holds the claim and the attempt is still wanted, so a photo deleted or
  merged away mid-import gets no more files. Once all five are stored it
  marks the attempt stored, then publishes the photo, only if the attempt is
  still the photo's current one. No transaction is held open during network
  or image work.

  Failures leave the photo hidden. A transient one (iNaturalist or storage
  unreachable, a 5xx) is retried with backoff and shown to editors as the
  photo's `last_error`; a permanent one (the photo is gone, its bytes aren't
  an image), or the last of `max_tries/0`, fails the photo and records a
  cleanup of the attempt's paths. An editor can then retry it
  (`Oaks.Images.retry_import/3`).

  Oban (`Oban.Lifeline`) may start a job again after a crash; the claim
  makes that harmless.
  """
  use Oban.Worker,
    queue: :images,
    # Oban's count includes snoozes; the attempt's own tries (max_tries/0)
    # decide when it fails.
    max_attempts: 20,
    unique: [keys: [:attempt_id], states: [:available, :scheduled, :retryable]]

  import Ecto.Query

  require Logger

  alias Oaks.Images
  alias Oaks.Images.{Image, ImportAttempt}
  alias Oaks.INaturalist
  alias Oaks.Repo
  alias Oaks.Storage.Images, as: ImageStorage
  alias Oaks.Storage.Variants

  @max_tries 5
  @timeout :timer.minutes(5)
  # Longer than the job may run (Oban stops it at @timeout), so no write of
  # a run can land after its lease ends.
  @lease_ms @timeout + :timer.minutes(1)

  @doc "How many runs an attempt gets before it fails."
  @spec max_tries() :: pos_integer()
  def max_tries, do: @max_tries

  @doc "How long a claim lasts, in milliseconds."
  @spec lease_ms() :: pos_integer()
  def lease_ms, do: @lease_ms

  @impl Oban.Worker
  def timeout(_job), do: @timeout

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"attempt_id" => attempt_id}}) do
    case claim(attempt_id) do
      {:ok, attempt} ->
        attempt |> run() |> finish(attempt)

      {:wait, seconds} ->
        {:snooze, seconds}

      :done ->
        :ok
    end
  end

  # -- Claiming --

  @doc false
  # Claims a queued attempt, or a running one whose lease has run out (its
  # run crashed). An attempt out of tries fails instead.
  @spec claim(integer()) :: {:ok, ImportAttempt.t()} | {:wait, pos_integer()} | :done
  def claim(attempt_id) do
    now = DateTime.utc_now()

    {:ok, result} = Repo.transaction(fn -> claim(Repo.get(ImportAttempt, attempt_id), now) end)
    result
  end

  defp claim(%ImportAttempt{state: "queued"} = attempt, now), do: take(attempt, now)

  defp claim(%ImportAttempt{state: "running", lease_until: until} = attempt, now) do
    if until && DateTime.after?(until, now),
      do: {:wait, max(DateTime.diff(until, now), 1)},
      else: take(attempt, now)
  end

  defp claim(_gone_or_finished, _now), do: :done

  defp take(%ImportAttempt{tries: tries} = attempt, _now) when tries >= @max_tries do
    fail!(attempt, :out_of_tries)
    :done
  end

  defp take(attempt, now) do
    claimed =
      attempt
      |> Ecto.Changeset.change(
        state: "running",
        lease_token: Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false),
        lease_until: DateTime.add(now, @lease_ms, :millisecond),
        tries: attempt.tries + 1
      )
      |> Repo.update!()

    {:ok, claimed}
  end

  # Whether this run still holds the attempt's claim, and its photo still
  # wants it: checked before every write.
  defp held?(%ImportAttempt{id: id, lease_token: token}) do
    now = DateTime.utc_now()

    from(a in ImportAttempt,
      join: i in Image,
      on: i.id == a.image_id and i.current_attempt_id == a.id,
      where:
        a.id == ^id and a.state == "running" and a.lease_token == ^token and
          a.lease_until > ^now
    )
    |> Repo.exists?()
  end

  # -- Running --

  defp run(%ImportAttempt{stored_at: %DateTime{}} = attempt), do: publish(attempt)

  defp run(attempt) do
    extension = Path.extname(attempt.original_path)

    with {:ok, original} <- download(attempt),
         {:ok, variants} <- resize(original, extension),
         :ok <- store(attempt, [{:original, original} | variants]),
         :ok <- mark_stored(attempt) do
      publish(attempt)
    end
  end

  defp download(attempt) do
    case INaturalist.download_photo(attempt.photo_url) do
      {:ok, bytes} -> {:ok, bytes}
      {:error, reason} -> {:error, {:download, reason}}
    end
  end

  defp resize(original, extension) do
    case Variants.generate(original, extension) do
      {:ok, variants} -> {:ok, variants}
      {:error, reason} -> {:error, {:resize, reason}}
    end
  end

  defp store(_attempt, []), do: :ok

  defp store(attempt, [{size, data} | rest]) do
    path = ImageStorage.variant_path(attempt.original_path, size)

    with {:held, true} <- {:held, held?(attempt)},
         :ok <- ImageStorage.put(path, data, ImageStorage.content_type(path)) do
      store(attempt, rest)
    else
      {:held, false} -> {:error, :released}
      {:error, reason} -> {:error, {:store, reason}}
    end
  end

  defp mark_stored(%ImportAttempt{id: id, lease_token: token}) do
    case from(a in ImportAttempt,
           where: a.id == ^id and a.state == "running" and a.lease_token == ^token
         )
         |> Repo.update_all(set: [stored_at: DateTime.utc_now(), updated_at: DateTime.utc_now()]) do
      {1, _} -> :ok
      {0, _} -> {:error, :released}
    end
  end

  # Publishes the photo, in one transaction, if this run still holds the
  # attempt and the attempt is still the photo's current one. Whoever
  # superseded it (a deletion, a merge) recorded the cleanup of its files.
  defp publish(attempt) do
    Repo.transaction(fn ->
      if held?(attempt) do
        image = Repo.get!(Image, attempt.image_id)

        image
        |> Ecto.Changeset.change(status: "ready", path: attempt.original_path, last_error: nil)
        |> Repo.update!()

        attempt
        |> Ecto.Changeset.change(
          state: "published",
          lease_token: nil,
          lease_until: nil,
          last_error: nil
        )
        |> Repo.update!()

        :published
      else
        Repo.rollback(:released)
      end
    end)
    |> case do
      {:ok, :published} ->
        Images.broadcast_image_changed(attempt.image_id)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  # -- Finishing --

  defp finish(:ok, _attempt), do: :ok

  # The attempt was cancelled, or another run took it over: nothing to do,
  # but let a waiting cleanup start now rather than when the lease ends.
  defp finish({:error, :released}, attempt) do
    release(attempt)
    :ok
  end

  defp finish({:error, reason}, attempt) do
    message = describe_error(reason)

    if permanent?(reason) or attempt.tries >= @max_tries do
      Logger.warning("Species photo import failed (attempt #{attempt.id}): #{message}")
      fail!(attempt, reason)
      {:cancel, message}
    else
      requeue(attempt, message)
      {:error, message}
    end
  end

  defp release(%ImportAttempt{id: id, lease_token: token}) do
    from(a in ImportAttempt, where: a.id == ^id and a.lease_token == ^token)
    |> Repo.update_all(set: [lease_token: nil, lease_until: nil, updated_at: DateTime.utc_now()])
  end

  # Back in the queue for Oban's retry, with the error shown on the photo.
  defp requeue(%ImportAttempt{id: id, lease_token: token, image_id: image_id}, message) do
    Repo.transaction(fn ->
      {count, _} =
        from(a in ImportAttempt,
          where: a.id == ^id and a.state == "running" and a.lease_token == ^token
        )
        |> Repo.update_all(
          set: [
            state: "queued",
            lease_token: nil,
            lease_until: nil,
            last_error: message,
            updated_at: DateTime.utc_now()
          ]
        )

      if count == 1 do
        from(i in Image, where: i.id == ^image_id and i.current_attempt_id == ^id)
        |> Repo.update_all(set: [last_error: message, updated_at: DateTime.utc_now(:second)])
      end
    end)

    Images.broadcast_image_changed(image_id)
  end

  @doc false
  # Fails the attempt and its photo (when it's still the photo's current
  # attempt), and records the cleanup of its paths, in one transaction.
  @spec fail!(ImportAttempt.t(), term()) :: :ok
  def fail!(%ImportAttempt{id: id}, reason) do
    message = describe_error(reason)

    {:ok, :ok} =
      Repo.transaction(fn -> fail_unfinished!(Repo.get!(ImportAttempt, id), message) end)

    Images.broadcast_image_changed(Repo.get!(ImportAttempt, id).image_id)
  end

  defp fail_unfinished!(%ImportAttempt{state: state} = attempt, message)
       when state in ["queued", "running"] do
    attempt =
      attempt
      |> Ecto.Changeset.change(
        state: "failed",
        lease_token: nil,
        lease_until: nil,
        last_error: message
      )
      |> Repo.update!()

    image =
      attempt.image_id &&
        Repo.one(
          from(i in Image,
            where: i.id == ^attempt.image_id and i.current_attempt_id == ^attempt.id
          )
        )

    if image do
      image |> Ecto.Changeset.change(status: "failed", last_error: message) |> Repo.update!()
    end

    Images.record_cleanup!([attempt], "import_failed", image)
    :ok
  end

  defp fail_unfinished!(_finished, _message), do: :ok

  # Retrying can't help: the photo is gone or isn't an image we can read.
  defp permanent?({:download, :invalid_url}), do: true
  defp permanent?({:download, {:http_error, status}}) when status in [408, 429], do: false
  defp permanent?({:download, {:http_error, status}}) when status in 400..499, do: true
  defp permanent?({:resize, _reason}), do: true
  defp permanent?(:out_of_tries), do: true
  defp permanent?(_reason), do: false

  @doc """
  What went wrong, in words for the editor who imported the photo.
  """
  @spec describe_error(term()) :: String.t()
  def describe_error({:download, :invalid_url}),
    do: "The photo's address isn't an iNaturalist photo address."

  def describe_error({:download, {:http_error, status}}) when status in [403, 404, 410],
    do: "iNaturalist no longer has this photo (HTTP #{status})."

  def describe_error({:download, {:http_error, status}}),
    do: "iNaturalist returned an error (HTTP #{status})."

  def describe_error({:download, %{__exception__: true} = e}),
    do: "Couldn't reach iNaturalist: #{Exception.message(e)}"

  def describe_error({:download, reason}),
    do: "Couldn't download the photo: #{inspect(reason)}"

  def describe_error({:resize, :too_many_pixels}),
    do: "The photo is too large to resize."

  def describe_error({:resize, _reason}),
    do: "The photo couldn't be read as an image."

  def describe_error({:store, reason}),
    do: "Couldn't store the photo: #{inspect(reason)}"

  def describe_error(:out_of_tries),
    do: "Gave up after #{@max_tries} tries."

  def describe_error(%{__exception__: true} = e), do: Exception.message(e)
  def describe_error(reason), do: inspect(reason)
end
