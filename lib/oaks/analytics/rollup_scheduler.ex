defmodule Oaks.Analytics.RollupScheduler do
  @moduledoc """
  Runs `Oaks.Analytics.Rollup.run/0` shortly after boot and then hourly.

  The rollup is idempotent and only processes finished days, so running it
  often just means a new day is summarized within an hour of midnight UTC,
  and a failed day is retried on the next run. Disabled in tests via
  `config :oaks, Oaks.Analytics.RollupScheduler, enabled: false`.
  """
  use GenServer

  require Logger

  alias Oaks.Analytics.Rollup

  @initial_delay :timer.minutes(1)
  @interval :timer.hours(1)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    Process.send_after(self(), :run, @initial_delay)
    {:ok, nil}
  end

  @impl true
  def handle_info(:run, state) do
    try do
      %{rolled_up: rolled_up, pruned: pruned} = Rollup.run()

      if rolled_up > 0 or pruned > 0 do
        Logger.info(
          "Analytics rollup: #{rolled_up} day(s) rolled up, #{pruned} raw row(s) pruned"
        )
      end
    rescue
      e -> Logger.error("Analytics rollup failed: #{Exception.message(e)}")
    end

    Process.send_after(self(), :run, @interval)
    {:noreply, state}
  end
end
