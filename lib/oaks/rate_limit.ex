defmodule Oaks.RateLimit do
  @moduledoc """
  In-memory rate limiting (Hammer, ETS backend), used for login attempts
  (`OaksWeb.LoginLimiter`). The app runs on one machine, so an in-memory
  count is the whole picture; it resets when the app restarts.
  """
  use Hammer, backend: :ets
end
