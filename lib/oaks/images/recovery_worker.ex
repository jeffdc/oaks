defmodule Oaks.Images.RecoveryWorker do
  @moduledoc """
  Makes sure all unfinished photo work has a job: run at boot and every 15
  minutes (`config :oaks, Oban`, crontab).

  Oban keeps jobs across restarts, so this is the backstop for work whose
  job is gone or gave up: every queued attempt, every running attempt whose
  lease has ended (its run died), and every cleanup not yet done gets a job
  (a no-op when it already has one waiting, `unique`). A crashed attempt
  that has used all its tries is failed and its files cleaned up.
  """
  use Oban.Worker, queue: :images, max_attempts: 3, unique: [period: 60]

  import Ecto.Query

  alias Oaks.Images.{Cleanup, CleanupWorker, ImportAttempt, ImportWorker}
  alias Oaks.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    resume()
    :ok
  end

  @doc """
  Enqueues the unfinished work (see the moduledoc). Returns how many
  attempts and cleanups it found.
  """
  @spec resume() :: %{attempts: non_neg_integer(), cleanups: non_neg_integer()}
  def resume do
    now = DateTime.utc_now()

    attempts =
      from(a in ImportAttempt,
        where:
          a.state == "queued" or
            (a.state == "running" and (is_nil(a.lease_until) or a.lease_until <= ^now))
      )
      |> Repo.all()

    for attempt <- attempts do
      if attempt.tries >= ImportWorker.max_tries(),
        do: ImportWorker.fail!(attempt, :out_of_tries),
        else: Oban.insert!(ImportWorker.new(%{attempt_id: attempt.id}))
    end

    cleanup_ids = from(c in Cleanup, where: c.state != "done", select: c.id) |> Repo.all()
    for id <- cleanup_ids, do: Oban.insert!(CleanupWorker.new(%{cleanup_id: id}))

    %{attempts: length(attempts), cleanups: length(cleanup_ids)}
  end
end
