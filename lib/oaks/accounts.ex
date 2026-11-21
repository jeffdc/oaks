defmodule Oaks.Accounts do
  @moduledoc """
  Editors and how they log in (item 0249).

  A login takes a password (Argon2id) and a second factor: a TOTP code from
  an authenticator app or a single-use recovery code (`SecondFactor`). TOTP
  secrets are encrypted at rest (`SecretBox`); session, setup and recovery
  tokens are stored only as hashes (`UserToken`, `RecoveryCode`).

  There is no sign-up. A user is created, or recovered, by a setup link
  (`create_setup_link/1`, run from `Oaks.Release.setup_link/1` over
  `fly ssh`). Opening the link sets the password and enrolls the
  authenticator app (`complete_setup/4`). The model allows any number of
  users; every user can edit.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Oaks.Accounts.{RecoveryCode, SecondFactor, SecretBox, User, UserToken}
  alias Oaks.Repo

  ## Users

  @doc "The user with `email`, or nil."
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.trim(email))
  end

  @doc "The user with `id`, or nil."
  def get_user(id), do: Repo.get(User, id)

  @doc "The user with `id`. Raises if there is none."
  def get_user!(id), do: Repo.get!(User, id)

  ## Logging in

  @doc """
  The first login step: the user with `email`, if `password` is theirs and
  they have finished setup.

  Runs a password check whether or not the email exists, so timing doesn't
  reveal which emails do.
  """
  @spec authenticate_by_password(String.t(), String.t()) :: {:ok, User.t()} | :error
  def authenticate_by_password(email, password) when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)

    if User.valid_password?(user, password) and User.set_up?(user),
      do: {:ok, user},
      else: :error
  end

  @doc """
  The second login step: checks a TOTP code or a recovery code, and uses it
  up so it can't be entered again.
  """
  @spec verify_second_factor(User.t(), String.t()) :: :ok | :error
  def verify_second_factor(%User{} = user, code) when is_binary(code) do
    if SecondFactor.totp_code?(code),
      do: verify_totp(user, code),
      else: use_recovery_code(user, code)
  end

  defp verify_totp(%User{totp_secret: box} = user, code) when is_binary(box) do
    with {:ok, secret} <- SecretBox.decrypt(box, totp_context(user)),
         {:ok, used_at} <- SecondFactor.verify_totp(secret, code, user.totp_last_used_at) do
      record_totp_use(user, used_at)
    end
  end

  defp verify_totp(_user, _code), do: :error

  # Compare-and-set on the last use, so two requests racing with the same
  # code can't both succeed.
  defp record_totp_use(user, used_at) do
    query =
      if user.totp_last_used_at,
        do:
          from(u in User,
            where: u.id == ^user.id and u.totp_last_used_at == ^user.totp_last_used_at
          ),
        else: from(u in User, where: u.id == ^user.id and is_nil(u.totp_last_used_at))

    case Repo.update_all(query, set: [totp_last_used_at: used_at]) do
      {1, _} -> :ok
      _ -> :error
    end
  end

  defp use_recovery_code(user, code) do
    now = DateTime.utc_now(:second)
    hashed = SecondFactor.hash_recovery_code(code)

    query =
      from c in RecoveryCode,
        where: c.user_id == ^user.id and c.hashed_code == ^hashed and is_nil(c.used_at)

    case Repo.update_all(query, set: [used_at: now]) do
      {1, _} -> :ok
      _ -> :error
    end
  end

  @doc "How many unused recovery codes the user has left."
  def count_unused_recovery_codes(%User{id: id}) do
    Repo.aggregate(from(c in RecoveryCode, where: c.user_id == ^id and is_nil(c.used_at)), :count)
  end

  @doc """
  Whether the user logged in within the last `minutes` (given as a negative
  number, as for `DateTime.add/3`). Sensitive changes require it.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  ## Sessions

  @doc "Creates a session token for `user` and returns the raw token for the cookie."
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  The user holding a valid session `token`, with the token's creation time:
  `{user, inserted_at}`, or nil.
  """
  def get_user_by_session_token(token) do
    token |> UserToken.verify_session_token_query() |> Repo.one()
  end

  @doc "Ends the session holding `token`."
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^UserToken.hash(token), context: "session"]))
    :ok
  end

  ## Setup

  @doc """
  Creates a one-time setup link token for `email`, creating the user if
  there is none yet. Any earlier setup link for the user stops working.

  For an existing user this is also account recovery: completing setup
  replaces the password, the authenticator app and the recovery codes, and
  ends every session.
  """
  @spec create_setup_link(String.t()) ::
          {:ok, User.t(), String.t()} | {:error, Ecto.Changeset.t()}
  def create_setup_link(email) when is_binary(email) do
    Repo.transaction(fn ->
      user = get_or_create_user(email)

      Repo.delete_all(from(t in UserToken, where: t.user_id == ^user.id and t.context == "setup"))
      {encoded, user_token} = UserToken.build_setup_token(user)
      Repo.insert!(user_token)
      {user, encoded}
    end)
    |> case do
      {:ok, {user, encoded}} -> {:ok, user, encoded}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp get_or_create_user(email) do
    with nil <- get_user_by_email(email),
         {:error, changeset} <- %User{} |> User.email_changeset(%{email: email}) |> Repo.insert() do
      Repo.rollback(changeset)
    else
      {:ok, %User{} = user} -> user
      %User{} = user -> user
    end
  end

  @doc "The user a valid setup token belongs to, or nil."
  def get_user_by_setup_token(encoded) when is_binary(encoded) do
    case UserToken.verify_setup_token_query(encoded) do
      {:ok, query} -> Repo.one(query)
      :error -> nil
    end
  end

  @setup_types %{password: :string, password_confirmation: :string, code: :string}

  @doc "A changeset for the setup form: a new password and a code from the new secret."
  def change_setup(attrs \\ %{}) do
    {%{}, @setup_types}
    |> Ecto.Changeset.cast(attrs, Map.keys(@setup_types))
    |> Ecto.Changeset.validate_required([:password, :code])
    |> Ecto.Changeset.validate_confirmation(:password, message: "does not match password")
    |> Ecto.Changeset.validate_length(:password, min: 12, max: 128)
  end

  @doc """
  Finishes setup from a setup link: sets the password, enrolls `totp_secret`
  (the code entered must come from it), replaces the recovery codes, and ends
  every session and setup link the user had.

  Returns the plain recovery codes, to show once, and the ended session
  tokens, to disconnect their LiveViews.
  """
  @spec complete_setup(User.t(), String.t(), binary(), map()) ::
          {:ok, %{user: User.t(), recovery_codes: [String.t()], expired_tokens: [UserToken.t()]}}
          | {:error, :invalid_token | Ecto.Changeset.t()}
  def complete_setup(%User{} = user, encoded_token, totp_secret, attrs) do
    changeset = change_setup(attrs)

    with {:ok, used_at} <- check_new_code(changeset, totp_secret),
         :ok <- check_setup_token(user, encoded_token) do
      codes = SecondFactor.new_recovery_codes()

      user_changes =
        Ecto.Changeset.change(user,
          hashed_password: Argon2.hash_pwd_salt(Ecto.Changeset.get_field(changeset, :password)),
          totp_secret: SecretBox.encrypt(totp_secret, totp_context(user)),
          totp_last_used_at: used_at
        )

      Multi.new()
      |> Multi.run(:claim, fn repo, _ -> claim_setup_token(repo, user, encoded_token) end)
      |> Multi.update(:user, user_changes)
      |> expire_tokens(user)
      |> replace_recovery_codes(user, codes)
      |> Repo.transaction()
      |> case do
        {:ok, %{user: user, expired: expired}} ->
          {:ok, %{user: user, recovery_codes: codes, expired_tokens: expired}}

        {:error, :claim, :invalid_token, _} ->
          {:error, :invalid_token}

        {:error, _step, %Ecto.Changeset{} = changeset, _} ->
          {:error, changeset}
      end
    end
  end

  # The code must come from the new secret; checked once, and its time
  # becomes the first `since`, so the code can't be replayed at login.
  defp check_new_code(changeset, secret) do
    code = Ecto.Changeset.get_field(changeset, :code)
    result = if code, do: SecondFactor.verify_totp(secret, code, nil), else: :error

    case result do
      {:ok, used_at} when changeset.valid? ->
        {:ok, used_at}

      {:ok, _} ->
        {:error, %{changeset | action: :validate}}

      :error when is_binary(code) ->
        changeset
        |> Ecto.Changeset.add_error(:code, "is not the current code from your authenticator app")
        |> Map.put(:action, :validate)
        |> then(&{:error, &1})

      :error ->
        {:error, %{changeset | action: :validate}}
    end
  end

  # Uses the setup token up inside the transaction, so two submissions of
  # the same link can't both complete.
  defp claim_setup_token(repo, user, encoded_token) do
    with {:ok, raw} <- Base.url_decode64(encoded_token, padding: false),
         {1, _} <-
           repo.delete_all(
             from(t in UserToken,
               where:
                 t.user_id == ^user.id and t.context == "setup" and
                   t.token == ^UserToken.hash(raw)
             )
           ) do
      {:ok, :claimed}
    else
      _ -> {:error, :invalid_token}
    end
  end

  defp check_setup_token(%User{id: id}, encoded_token) do
    case get_user_by_setup_token(encoded_token) do
      %User{id: ^id} -> :ok
      _ -> {:error, :invalid_token}
    end
  end

  ## Settings

  @doc "A changeset for the change-password form."
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Changes the password and ends every session, returning the ended session
  tokens so their LiveViews can be disconnected. The caller logs the user
  back in.
  """
  def update_user_password(user, attrs) do
    Multi.new()
    |> Multi.update(:user, User.password_changeset(user, attrs))
    |> expire_tokens(user)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user, expired: expired}} -> {:ok, {user, expired}}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc "Replaces the user's recovery codes and returns the new ones, to show once."
  def regenerate_recovery_codes(%User{} = user) do
    codes = SecondFactor.new_recovery_codes()
    {:ok, _} = Multi.new() |> replace_recovery_codes(user, codes) |> Repo.transaction()
    codes
  end

  # Every session and setup token the user has goes; the session ones are
  # returned for OaksWeb.UserAuth.disconnect_sessions/1.
  defp expire_tokens(multi, user) do
    multi
    |> Multi.all(
      :expired,
      from(t in UserToken, where: t.user_id == ^user.id and t.context == "session")
    )
    |> Multi.delete_all(:tokens, from(t in UserToken, where: t.user_id == ^user.id))
  end

  defp replace_recovery_codes(multi, user, codes) do
    now = DateTime.utc_now(:second)

    rows =
      Enum.map(
        codes,
        &%{user_id: user.id, hashed_code: SecondFactor.hash_recovery_code(&1), inserted_at: now}
      )

    multi
    |> Multi.delete_all(:old_codes, from(c in RecoveryCode, where: c.user_id == ^user.id))
    |> Multi.insert_all(:codes, RecoveryCode, rows)
  end

  defp totp_context(%User{id: id}), do: "totp:#{id}"
end
