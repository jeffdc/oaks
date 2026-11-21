defmodule Oaks.Accounts.UserToken do
  @moduledoc """
  Session and setup tokens.

  A token is 32 random bytes. Only its SHA-256 hash is stored, so a copy of
  the database (a backup, `make download-db`) can't be turned into a login:

    * `"session"` - the raw token is in the user's encrypted session cookie.
      Valid for 14 days from when it was issued; `OaksWeb.UserAuth` issues a
      fresh one each week the session is used.
    * `"setup"` - the raw token is in a one-time setup link printed by the
      release command (`Oaks.Release.setup_link/1`). Valid for 15 minutes.
  """
  use Ecto.Schema
  import Ecto.Query
  alias Oaks.Accounts.UserToken

  @hash_algorithm :sha256
  @rand_size 32

  @session_validity_in_days 14
  @setup_validity_in_minutes 15

  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    field :authenticated_at, :utc_datetime
    belongs_to :user, Oaks.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc "Days a session token stays valid."
  def session_validity_in_days, do: @session_validity_in_days

  @doc "The stored form of a raw token."
  def hash(token) when is_binary(token), do: :crypto.hash(@hash_algorithm, token)

  @doc """
  Builds a session token. Returns the raw token, for the cookie, and the
  row to insert, which holds its hash.
  """
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    dt = user.authenticated_at || DateTime.utc_now(:second)

    {token,
     %UserToken{token: hash(token), context: "session", user_id: user.id, authenticated_at: dt}}
  end

  @doc """
  The query for the user holding a valid session token, with the token's
  creation time: `{user, inserted_at}`.
  """
  def verify_session_token_query(token) do
    from t in by_token_and_context_query(hash(token), "session"),
      join: user in assoc(t, :user),
      where: t.inserted_at > ago(@session_validity_in_days, "day"),
      select: {%{user | authenticated_at: t.authenticated_at}, t.inserted_at}
  end

  @doc """
  Builds a setup token. Returns the raw token, URL-encoded for the link, and
  the row to insert.
  """
  def build_setup_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)

    {Base.url_encode64(token, padding: false),
     %UserToken{token: hash(token), context: "setup", user_id: user.id}}
  end

  @doc "The query for the user holding a valid setup token, or `:error` for a malformed one."
  def verify_setup_token_query(encoded) do
    case Base.url_decode64(encoded, padding: false) do
      {:ok, token} ->
        {:ok,
         from(t in by_token_and_context_query(hash(token), "setup"),
           join: user in assoc(t, :user),
           where: t.inserted_at > ago(^@setup_validity_in_minutes, "minute"),
           select: user
         )}

      :error ->
        :error
    end
  end

  defp by_token_and_context_query(hashed_token, context) do
    from UserToken, where: [token: ^hashed_token, context: ^context]
  end
end
