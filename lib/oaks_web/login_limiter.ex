defmodule OaksWeb.LoginLimiter do
  @moduledoc """
  Rate limits for the login steps (password, then code), counted in memory
  by `Oaks.RateLimit`. Every attempt counts, successful or not:

    * per client IP (Fly's `fly-client-ip`, see
      `OaksWeb.Plugs.Analytics.client_ip/1`): `:per_ip` attempts per 15 minutes
      (default 10), password and code attempts counted separately;
    * per account (by email for the password step, by user for the code step):
      `:per_account` attempts per hour (default 20), whichever IPs they come from.

  Limits come from `config :oaks, :login_rate_limits` so tests can change them.
  """

  alias OaksWeb.Plugs.Analytics

  @ip_window :timer.minutes(15)
  @account_window :timer.hours(1)

  @doc "Counts an attempt at `step` (`:password` or `:code`) for `account`; `:ok` or `:deny`."
  @spec hit(Plug.Conn.t(), :password | :code, String.t()) :: :ok | :deny
  def hit(conn, step, account) when step in [:password, :code] and is_binary(account) do
    ip = Analytics.client_ip(conn)
    limits = limits()

    with {:allow, _} <- Oaks.RateLimit.hit("login:#{step}:ip:#{ip}", @ip_window, limits[:per_ip]),
         {:allow, _} <-
           Oaks.RateLimit.hit(
             "login:#{step}:account:#{account |> String.trim() |> String.downcase()}",
             @account_window,
             limits[:per_account]
           ) do
      :ok
    else
      {:deny, _} -> :deny
    end
  end

  defp limits do
    Keyword.merge(
      [per_ip: 10, per_account: 20],
      Application.get_env(:oaks, :login_rate_limits, [])
    )
  end
end
