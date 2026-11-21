defmodule Oaks.Accounts.User do
  @moduledoc """
  An editor who can log in.

  A user is created with only an email (`Oaks.Accounts.create_setup_link/1`)
  and can log in once setup has set a password and a TOTP secret.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :totp_secret, :binary, redact: true
    field :totp_last_used_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc "A changeset for creating a user from an email."
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> update_change(:email, &String.trim/1)
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Oaks.Repo)
    |> unique_constraint(:email)
  end

  @doc """
  A changeset for setting the password.

  The length is capped because very long passwords are expensive to hash.

  ## Options

    * `:hash_password` - hashes the password and clears the plain one from
      the changeset. Set to `false` to validate a form without hashing.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_length(:password, min: 12, max: 128)
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    password = get_change(changeset, :password)

    if Keyword.get(opts, :hash_password, true) && password && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Argon2.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Verifies the password.

  With no user or no password set, runs `Argon2.no_user_verify/0` so the
  response takes as long as a real check and doesn't reveal which emails exist.
  """
  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and is_binary(password) and byte_size(password) > 0 do
    Argon2.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Argon2.no_user_verify()
    false
  end

  @doc "Whether the user has finished setup and can log in."
  def set_up?(%__MODULE__{hashed_password: password, totp_secret: secret}),
    do: is_binary(password) and is_binary(secret)
end
