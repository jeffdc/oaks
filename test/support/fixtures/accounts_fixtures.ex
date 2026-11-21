defmodule Oaks.AccountsFixtures do
  @moduledoc """
  Test helpers for users and logins (`Oaks.Accounts`).

  `user_fixture/1` makes a fully set-up user the way production does: a
  setup link, then `Accounts.complete_setup/4` with a password and a code
  from a known TOTP secret.
  """

  import Ecto.Query

  alias Oaks.Accounts
  alias Oaks.Accounts.{SecretBox, UserToken}

  def unique_user_email, do: "user#{System.unique_integer([:positive])}@example.com"
  def valid_user_password, do: "a long enough password"

  @doc "A set-up user who can log in with `valid_user_password/0` and `next_totp_code/1`."
  def user_fixture(attrs \\ %{}) do
    email = attrs[:email] || unique_user_email()
    password = attrs[:password] || valid_user_password()
    secret = Accounts.SecondFactor.new_totp_secret()

    {:ok, user, token} = Accounts.create_setup_link(email)

    {:ok, %{user: user, recovery_codes: codes}} =
      Accounts.complete_setup(user, token, secret, %{
        "password" => password,
        "password_confirmation" => password,
        "code" => NimbleTOTP.verification_code(secret)
      })

    Process.put({__MODULE__, :recovery_codes, user.id}, codes)
    user
  end

  @doc "A user created from a setup link who hasn't finished setup, with the link's token."
  def pending_user_fixture(email \\ unique_user_email()) do
    {:ok, user, token} = Accounts.create_setup_link(email)
    {user, token}
  end

  @doc "The user's TOTP secret, decrypted."
  def totp_secret(user) do
    user = Accounts.get_user!(user.id)
    {:ok, secret} = SecretBox.decrypt(user.totp_secret, "totp:#{user.id}")
    secret
  end

  @doc """
  A TOTP code the user can enter now: the next period's, since the current
  period's code was used up by setup or an earlier login.
  """
  def next_totp_code(user, offset \\ 30) do
    NimbleTOTP.verification_code(totp_secret(user), time: System.os_time(:second) + offset)
  end

  @doc "The recovery codes `user_fixture/1` was given."
  def recovery_codes(user), do: Process.get({__MODULE__, :recovery_codes, user.id})

  @doc "Sets when a session token's login happened, to test sudo mode and expiry."
  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Oaks.Repo.update_all(
      from(t in UserToken, where: t.token == ^UserToken.hash(token)),
      set: [authenticated_at: authenticated_at]
    )
  end

  @doc "Moves a token's creation time back, to test expiry and renewal."
  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    Oaks.Repo.update_all(
      from(t in UserToken, where: t.token == ^UserToken.hash(token)),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end
