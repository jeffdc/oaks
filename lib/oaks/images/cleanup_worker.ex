defmodule Oaks.Images.CleanupWorker do
  @moduledoc """
  Removes the files of an `Oaks.Images.Cleanup`: deletes every path, then
  asks the CDN to invalidate them and waits for the invalidation to
  complete. Only then is the cleanup `done`.

  It first waits while any of the cleanup's attempts is still leased to an
  import run (`Oaks.Images.ImportWorker`), so a run's last write can't land
  after its files were deleted. Each step is safe to repeat: deleting a
  missing file succeeds, and the invalidation's caller reference is fixed
  per cleanup, so asking again returns the same invalidation. Failures are
  recorded on the cleanup and retried with backoff, for as long as it takes
  (`Oaks.Images.RecoveryWorker` re-enqueues any whose job gave up).
  """
  use Oban.Worker,
    queue: :images,
    max_attempts: 50,
    unique: [keys: [:cleanup_id], states: [:available, :scheduled, :retryable]]

  import Ecto.Query

  require Logger

  alias Oaks.Images.{Cleanup, ImportAttempt}
  alias Oaks.Repo
  alias Oaks.Storage.Images, as: ImageStorage

  # How often to check an invalidation in progress, or a lease, in seconds.
  @poll 30

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}), do: min(15 * Integer.pow(2, attempt), 3600)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"cleanup_id" => id}}) do
    case Repo.get(Cleanup, id) do
      %Cleanup{state: state} = cleanup when state != "done" ->
        case lease_wait(cleanup) do
          0 -> step(cleanup)
          seconds -> {:snooze, seconds}
        end

      _done_or_missing ->
        :ok
    end
  end

  # Seconds until the latest lease on the cleanup's attempts ends (at most
  # @poll: a run that finishes early releases its lease), or 0 when none is
  # held.
  defp lease_wait(%Cleanup{attempt_ids: ids}) do
    now = DateTime.utc_now()

    from(a in ImportAttempt,
      where: a.id in ^ids and not is_nil(a.lease_until) and a.lease_until > ^now,
      select: max(a.lease_until)
    )
    |> Repo.one()
    |> case do
      nil -> 0
      until -> until |> DateTime.diff(now) |> max(1) |> min(@poll)
    end
  end

  defp step(%Cleanup{state: "deleting"} = cleanup) do
    case ImageStorage.delete(cleanup.paths) do
      :ok -> cleanup |> save(state: "invalidating", last_error: nil) |> step()
      {:error, reason} -> failed(cleanup, {:delete, reason})
    end
  end

  defp step(%Cleanup{state: "invalidating", invalidation_id: nil} = cleanup) do
    case ImageStorage.invalidate(cleanup.paths, caller_reference(cleanup)) do
      {:ok, invalidation_id} -> cleanup |> save(invalidation_id: invalidation_id) |> step()
      {:error, reason} -> failed(cleanup, {:invalidate, reason})
    end
  end

  defp step(%Cleanup{state: "invalidating", invalidation_id: invalidation_id} = cleanup) do
    case ImageStorage.invalidation_status(invalidation_id) do
      {:ok, :completed} ->
        save(cleanup, state: "done", last_error: nil, completed_at: DateTime.utc_now())
        :ok

      {:ok, :in_progress} ->
        {:snooze, @poll}

      {:error, reason} ->
        failed(cleanup, {:invalidation_status, reason})
    end
  end

  # Unique to this cleanup even if the database is rebuilt and IDs repeat.
  defp caller_reference(%Cleanup{id: id, inserted_at: inserted_at}),
    do: "oaks-image-cleanup-#{id}-#{DateTime.to_unix(inserted_at, :microsecond)}"

  defp save(cleanup, changes) do
    cleanup |> Ecto.Changeset.change(changes) |> Repo.update!()
  end

  defp failed(cleanup, reason) do
    message = inspect(reason)
    Logger.warning("Species photo cleanup failed (cleanup #{cleanup.id}): #{message}")
    save(cleanup, tries: cleanup.tries + 1, last_error: message)
    {:error, message}
  end
end
