defmodule Oaks.Accounts.ApiToken do
  @moduledoc """
  A token an editor issues to an agent for the private API (item fbd0).

  A token is `oak_` and 32 random bytes, URL-safe base64. The prefix makes a
  leaked token easy to spot. Only its SHA-256 hash is stored, so the token is
  shown once, when it is issued, and a copy of the database can't be turned
  into API access.

  Each token has a name, the scopes it grants (`scopes/0`), and an expiry the
  editor picks when issuing it (`lifetimes_in_days/0`). Revoking a token
  deletes it. Tokens survive a password change; completing setup from a setup
  link (account recovery) deletes them all.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  import Oaks.ChangesetHelpers

  alias Oaks.Accounts.ApiToken

  @prefix "oak_"
  @rand_size 32

  @scopes ~w(materials:read packages:submit)
  @lifetimes_in_days [30, 90, 365]
  @default_lifetime_in_days 90

  @type t :: %__MODULE__{}

  schema "api_tokens" do
    field :name, :string
    field :hashed_token, :binary, redact: true
    field :scopes, {:array, :string}, default: []
    field :lifetime_in_days, :integer, virtual: true, default: @default_lifetime_in_days
    field :expires_at, :utc_datetime
    field :last_used_at, :utc_datetime
    belongs_to :user, Oaks.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  The scopes a token can grant:

    * `"materials:read"` - read private material.
    * `"packages:submit"` - submit import packages.
  """
  def scopes, do: @scopes

  @doc "The lifetimes, in days, an editor can pick from."
  def lifetimes_in_days, do: @lifetimes_in_days

  @doc "The stored form of a raw token."
  def hash(token) when is_binary(token), do: :crypto.hash(:sha256, token)

  @doc "A changeset for the new-token form: a name, scopes and a lifetime."
  def changeset(token \\ %ApiToken{}, attrs) do
    token
    |> cast(attrs, [:name, :scopes, :lifetime_in_days])
    |> trim_strings()
    |> update_change(:scopes, fn scopes -> scopes |> Enum.reject(&(&1 == "")) |> Enum.uniq() end)
    |> validate_required([:name, :lifetime_in_days])
    |> validate_length(:name, max: 80)
    |> validate_some_scope()
    |> validate_subset(:scopes, @scopes)
    |> validate_inclusion(:lifetime_in_days, @lifetimes_in_days)
  end

  # Not validate_length/3: it only checks a change, and a form with no box
  # ticked may send no scopes at all.
  defp validate_some_scope(changeset) do
    if get_field(changeset, :scopes) in [nil, []],
      do: add_error(changeset, :scopes, "pick at least one"),
      else: changeset
  end

  @doc """
  Builds a token for `user` from the form's `attrs`. Returns the raw token,
  to show once, and the changeset to insert, which holds its hash.
  """
  def build(user, attrs) do
    raw = @prefix <> Base.url_encode64(:crypto.strong_rand_bytes(@rand_size), padding: false)
    changeset = changeset(%ApiToken{user_id: user.id}, attrs)
    days = get_field(changeset, :lifetime_in_days) || @default_lifetime_in_days

    changeset =
      changeset
      |> put_change(:hashed_token, hash(raw))
      |> put_change(:expires_at, DateTime.add(DateTime.utc_now(:second), days, :day))

    {raw, changeset}
  end

  @doc "Whether the token's expiry has passed."
  def expired?(%ApiToken{expires_at: expires_at}),
    do: DateTime.compare(expires_at, DateTime.utc_now()) != :gt

  @doc "Whether the token grants `scope`."
  def grants?(%ApiToken{scopes: scopes}, scope), do: scope in scopes

  @doc """
  The query for the unexpired token matching `raw`, with its user preloaded,
  or `:error` if `raw` isn't shaped like a token.
  """
  def verify_query(@prefix <> _ = raw) do
    {:ok,
     from(t in ApiToken,
       join: user in assoc(t, :user),
       where: t.hashed_token == ^hash(raw) and t.expires_at > ^DateTime.utc_now(:second),
       preload: [user: user]
     )}
  end

  def verify_query(_raw), do: :error
end
