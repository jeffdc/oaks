defmodule OaksWeb.ImportDryRunToken do
  @moduledoc """
  The token a dry run of an import returns and its apply must carry
  (decision 62ae).

  It is a stateless `Phoenix.Token`, valid for 24 hours, that binds:

    * the SHA-256 of the dry-run request's raw body, so only the exact
      bytes that were dry-run can apply;
    * the agent token that ran the dry run, by the first 8 bytes of its
      stored hash (not its id: SQLite can reuse a revoked token's id);
    * the dry run's plan digest (`Oaks.Import.dry_run/2`), so an apply whose
      result would differ from the report is refused.
  """

  alias Oaks.Accounts.ApiToken

  @salt "oaks import dry run"
  @max_age 24 * 60 * 60

  @type error :: :missing | :expired | :invalid | :body_mismatch | :other_token

  @doc "How long a token is valid, in seconds."
  @spec max_age() :: pos_integer()
  def max_age, do: @max_age

  @doc """
  Signs a token for a dry run of the body hashing to `body_sha256`, run with
  `api_token`. `opts` go to `Phoenix.Token.sign/4` (tests pass `:signed_at`).
  """
  @spec sign(ApiToken.t(), binary(), binary(), keyword()) :: String.t()
  def sign(%ApiToken{} = api_token, body_sha256, plan_digest, opts \\ []) do
    data = %{b: body_sha256, t: fingerprint(api_token), p: plan_digest}
    Phoenix.Token.sign(OaksWeb.Endpoint, @salt, data, opts)
  end

  @doc """
  Checks `token` (nil when the request had none) for an apply of the body
  hashing to `body_sha256` with `api_token`, and returns the dry run's plan
  digest.
  """
  @spec verify(String.t() | nil, ApiToken.t(), binary()) :: {:ok, binary()} | {:error, error()}
  def verify(nil, _api_token, _body_sha256), do: {:error, :missing}

  def verify(token, %ApiToken{} = api_token, body_sha256) when is_binary(token) do
    case Phoenix.Token.verify(OaksWeb.Endpoint, @salt, token, max_age: @max_age) do
      {:ok, %{b: body, t: fingerprint, p: plan_digest}} ->
        cond do
          fingerprint != fingerprint(api_token) -> {:error, :other_token}
          body != body_sha256 -> {:error, :body_mismatch}
          true -> {:ok, plan_digest}
        end

      {:ok, _other} ->
        {:error, :invalid}

      {:error, :expired} ->
        {:error, :expired}

      {:error, _} ->
        {:error, :invalid}
    end
  end

  defp fingerprint(%ApiToken{hashed_token: hashed}), do: binary_part(hashed, 0, 8)
end
