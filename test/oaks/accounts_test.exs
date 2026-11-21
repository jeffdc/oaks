defmodule Oaks.AccountsTest do
  use Oaks.DataCase

  import Ecto.Query
  import Oaks.AccountsFixtures

  alias Oaks.Accounts
  alias Oaks.Accounts.{ApiToken, RecoveryCode, SecretBox, User, UserToken}

  describe "create_setup_link/1" do
    test "creates a user with no password or second factor yet" do
      {:ok, user, token} = Accounts.create_setup_link("new@example.com")

      assert user.email == "new@example.com"
      refute user.hashed_password
      refute user.totp_secret
      refute User.set_up?(user)
      assert Accounts.get_user_by_setup_token(token).id == user.id
    end

    test "reuses an existing user and stops earlier links working" do
      {:ok, user, first} = Accounts.create_setup_link("again@example.com")
      {:ok, same, second} = Accounts.create_setup_link("again@example.com")

      assert same.id == user.id
      refute Accounts.get_user_by_setup_token(first)
      assert Accounts.get_user_by_setup_token(second)
    end

    test "rejects a malformed email" do
      assert {:error, changeset} = Accounts.create_setup_link("not an email")
      assert %{email: [_]} = errors_on(changeset)
    end

    test "stores only a hash of the token" do
      {:ok, user, token} = Accounts.create_setup_link("hash@example.com")
      {:ok, raw} = Base.url_decode64(token, padding: false)
      [row] = Repo.all(from t in UserToken, where: t.user_id == ^user.id)

      assert row.token == UserToken.hash(raw)
      refute row.token == raw
    end

    test "a link expires after 15 minutes" do
      {:ok, user, token} = Accounts.create_setup_link("old@example.com")
      old = DateTime.add(DateTime.utc_now(:second), -16, :minute)
      Repo.update_all(from(t in UserToken, where: t.user_id == ^user.id), set: [inserted_at: old])

      refute Accounts.get_user_by_setup_token(token)
    end

    test "ignores a malformed token" do
      refute Accounts.get_user_by_setup_token("not base64!")
    end
  end

  describe "complete_setup/4" do
    setup do
      {user, token} = pending_user_fixture()
      %{user: user, token: token, secret: Accounts.SecondFactor.new_totp_secret()}
    end

    defp setup_attrs(secret, overrides \\ %{}) do
      Map.merge(
        %{
          "password" => valid_user_password(),
          "password_confirmation" => valid_user_password(),
          "code" => NimbleTOTP.verification_code(secret)
        },
        overrides
      )
    end

    test "sets the password and an encrypted TOTP secret, and returns recovery codes", ctx do
      assert {:ok, %{user: user, recovery_codes: codes}} =
               Accounts.complete_setup(ctx.user, ctx.token, ctx.secret, setup_attrs(ctx.secret))

      assert User.set_up?(user)
      assert User.valid_password?(user, valid_user_password())
      refute user.totp_secret == ctx.secret
      assert SecretBox.decrypt(user.totp_secret, "totp:#{user.id}") == {:ok, ctx.secret}
      assert length(codes) == 10
      assert Accounts.count_unused_recovery_codes(user) == 10
      refute Accounts.get_user_by_setup_token(ctx.token)
    end

    test "rejects a code that doesn't come from the new secret", ctx do
      other = Accounts.SecondFactor.new_totp_secret()
      attrs = setup_attrs(ctx.secret, %{"code" => NimbleTOTP.verification_code(other)})

      assert {:error, changeset} = Accounts.complete_setup(ctx.user, ctx.token, ctx.secret, attrs)
      assert %{code: [_]} = errors_on(changeset)
      refute User.set_up?(Accounts.get_user!(ctx.user.id))
    end

    test "rejects a short or unconfirmed password", ctx do
      short =
        setup_attrs(ctx.secret, %{"password" => "short", "password_confirmation" => "short"})

      assert {:error, changeset} = Accounts.complete_setup(ctx.user, ctx.token, ctx.secret, short)
      assert %{password: ["should be at least 12 character(s)"]} = errors_on(changeset)

      mismatch = setup_attrs(ctx.secret, %{"password_confirmation" => "something else entirely"})

      assert {:error, changeset} =
               Accounts.complete_setup(ctx.user, ctx.token, ctx.secret, mismatch)

      assert %{password_confirmation: ["does not match password"]} = errors_on(changeset)
    end

    test "refuses a used or foreign token", ctx do
      {other, other_token} = pending_user_fixture()
      attrs = setup_attrs(ctx.secret)

      assert {:error, :invalid_token} =
               Accounts.complete_setup(ctx.user, other_token, ctx.secret, attrs)

      assert {:error, :invalid_token} =
               Accounts.complete_setup(other, ctx.token, ctx.secret, attrs)
    end

    test "on an existing user, replaces the factors and ends every session" do
      user = user_fixture()
      session = Accounts.generate_user_session_token(user)
      old_codes = recovery_codes(user)
      {:ok, _, token} = Accounts.create_setup_link(user.email)
      secret = Accounts.SecondFactor.new_totp_secret()

      assert {:ok, %{expired_tokens: [%UserToken{}]}} =
               Accounts.complete_setup(user, token, secret, setup_attrs(secret))

      refute Accounts.get_user_by_session_token(session)
      assert Accounts.verify_second_factor(Accounts.get_user!(user.id), hd(old_codes)) == :error
    end
  end

  describe "authenticate_by_password/2" do
    test "accepts the right password for a set-up user" do
      user = user_fixture()

      assert {:ok, %User{id: id}} =
               Accounts.authenticate_by_password(user.email, valid_user_password())

      assert id == user.id
    end

    test "ignores the case of the email" do
      user = user_fixture()

      assert {:ok, _} =
               Accounts.authenticate_by_password(String.upcase(user.email), valid_user_password())
    end

    test "refuses a wrong password, an unknown email and an unfinished setup" do
      user = user_fixture()
      {pending, _token} = pending_user_fixture()

      assert Accounts.authenticate_by_password(user.email, "the wrong password") == :error

      assert Accounts.authenticate_by_password("nobody@example.com", valid_user_password()) ==
               :error

      assert Accounts.authenticate_by_password(pending.email, "") == :error
    end
  end

  describe "verify_second_factor/2" do
    setup do
      %{user: user_fixture()}
    end

    test "accepts the next TOTP code once", %{user: user} do
      code = next_totp_code(user)
      assert Accounts.verify_second_factor(user, code) == :ok
      assert Accounts.verify_second_factor(Accounts.get_user!(user.id), code) == :error
    end

    test "refuses the code setup already used", %{user: user} do
      code = NimbleTOTP.verification_code(totp_secret(user))
      assert Accounts.verify_second_factor(user, code) == :error
    end

    test "refuses a stale struct racing a newer use", %{user: user} do
      assert Accounts.verify_second_factor(user, next_totp_code(user)) == :ok
      # `user` still holds the old last-use time: the compare-and-set fails.
      assert Accounts.verify_second_factor(user, next_totp_code(user, 30)) == :error
    end

    test "refuses codes from far outside the clock-drift window", %{user: user} do
      assert Accounts.verify_second_factor(user, next_totp_code(user, 120)) == :error
    end

    test "accepts each recovery code once, ignoring case and dashes", %{user: user} do
      [code | _] = recovery_codes(user)
      typed = code |> String.downcase() |> String.replace("-", " ")

      assert Accounts.verify_second_factor(user, typed) == :ok
      assert Accounts.verify_second_factor(user, code) == :error
      assert Accounts.count_unused_recovery_codes(user) == 9
    end

    test "refuses another user's recovery code", %{user: user} do
      other = user_fixture()
      assert Accounts.verify_second_factor(user, hd(recovery_codes(other))) == :error
    end

    test "refuses rubbish", %{user: user} do
      assert Accounts.verify_second_factor(user, "") == :error
      assert Accounts.verify_second_factor(user, "abcdef") == :error
    end
  end

  describe "sessions" do
    setup do
      %{user: user_fixture()}
    end

    test "a session token finds its user and is stored hashed", %{user: user} do
      token = Accounts.generate_user_session_token(user)

      assert {found, _inserted_at} = Accounts.get_user_by_session_token(token)
      assert found.id == user.id
      assert found.authenticated_at
      refute Repo.get_by(UserToken, token: token)
      assert Repo.get_by(UserToken, token: UserToken.hash(token), context: "session")
    end

    test "a session token expires after 14 days", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      offset_user_token(token, -15, :day)
      refute Accounts.get_user_by_session_token(token)
    end

    test "deleting a session token ends it", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "sudo_mode?/2" do
    test "is true within 20 minutes of the login" do
      now = DateTime.utc_now()
      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -19, :minute)})
      refute Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -21, :minute)})
      refute Accounts.sudo_mode?(%User{})
    end
  end

  describe "update_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "changes the password and ends every session", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      new = "a different long password"

      assert {:ok, {user, [%UserToken{}]}} =
               Accounts.update_user_password(user, %{
                 "password" => new,
                 "password_confirmation" => new
               })

      assert User.valid_password?(user, new)
      refute Accounts.get_user_by_session_token(token)
    end

    test "validates the new password", %{user: user} do
      assert {:error, changeset} =
               Accounts.update_user_password(user, %{
                 "password" => "short",
                 "password_confirmation" => "x"
               })

      assert %{password: [_], password_confirmation: [_]} = errors_on(changeset)
    end
  end

  describe "regenerate_recovery_codes/1" do
    test "replaces the old codes" do
      user = user_fixture()
      old = recovery_codes(user)
      new = Accounts.regenerate_recovery_codes(user)

      assert length(new) == 10
      assert Enum.all?(new, &(&1 =~ ~r/^[A-Z2-7]{4}(-[A-Z2-7]{4}){3}$/))
      assert Accounts.verify_second_factor(user, hd(old)) == :error
      assert Accounts.verify_second_factor(user, hd(new)) == :ok
      assert Repo.aggregate(from(c in RecoveryCode, where: c.user_id == ^user.id), :count) == 10
    end
  end

  describe "agent tokens" do
    setup do
      %{user: user_fixture()}
    end

    test "a new token is prefixed, stored hashed, and found by its raw form", %{user: user} do
      {:ok, raw, token} =
        Accounts.create_api_token(user, %{
          "name" => "  importer ",
          "scopes" => ["", "packages:submit"],
          "lifetime_in_days" => "30"
        })

      assert "oak_" <> _ = raw
      assert token.name == "importer"
      assert token.scopes == ["packages:submit"]
      assert DateTime.diff(token.expires_at, DateTime.utc_now(), :day) in 29..30
      assert Repo.get!(ApiToken, token.id).hashed_token == ApiToken.hash(raw)
      refute Repo.exists?(from(t in ApiToken, where: t.hashed_token == ^raw))

      assert {:ok, found} = Accounts.fetch_api_token(raw)
      assert found.id == token.id
      assert found.user.id == user.id
      assert found.scopes == ["packages:submit"]
    end

    test "lasts 90 days unless another lifetime is picked", %{user: user} do
      {:ok, _raw, token} =
        Accounts.create_api_token(user, %{"name" => "x", "scopes" => ["materials:read"]})

      assert DateTime.diff(token.expires_at, DateTime.utc_now(), :day) in 89..90
    end

    test "needs a name, a known scope and a listed lifetime", %{user: user} do
      assert {:error, changeset} = Accounts.create_api_token(user, %{"name" => " "})
      assert %{name: ["can't be blank"], scopes: ["pick at least one"]} = errors_on(changeset)

      assert {:error, changeset} =
               Accounts.create_api_token(user, %{
                 "name" => "x",
                 "scopes" => ["admin"],
                 "lifetime_in_days" => "7"
               })

      assert %{scopes: ["has an invalid entry"], lifetime_in_days: ["is invalid"]} =
               errors_on(changeset)
    end

    test "an unknown, malformed or expired token is refused", %{user: user} do
      {raw, token} = api_token_fixture(user)

      assert Accounts.fetch_api_token("oak_" <> String.duplicate("A", 43)) == :error
      assert Accounts.fetch_api_token(String.replace_prefix(raw, "oak_", "")) == :error
      assert Accounts.fetch_api_token("") == :error

      set_api_token_expiry(token, -1, :second)
      assert Accounts.fetch_api_token(raw) == :error
      assert ApiToken.expired?(Repo.get!(ApiToken, token.id))
    end

    test "records when it was last used", %{user: user} do
      {raw, token} = api_token_fixture(user)
      refute token.last_used_at

      {:ok, used} = Accounts.fetch_api_token(raw)
      assert used.last_used_at
      assert Repo.get!(ApiToken, token.id).last_used_at == used.last_used_at
    end

    test "lists the user's tokens, newest first", %{user: user} do
      {_, first} = api_token_fixture(user, %{"name" => "first"})
      {_, second} = api_token_fixture(user, %{"name" => "second"})
      api_token_fixture(user_fixture())

      assert Enum.map(Accounts.list_api_tokens(user), & &1.id) == [second.id, first.id]
    end

    test "revoking deletes the token; another user's token can't be revoked", %{user: user} do
      {raw, token} = api_token_fixture(user)
      {other_raw, other} = api_token_fixture(user_fixture())

      assert Accounts.delete_api_token(user, other.id) == :error
      assert {:ok, _} = Accounts.fetch_api_token(other_raw)

      assert Accounts.delete_api_token(user, token.id) == :ok
      assert Accounts.fetch_api_token(raw) == :error
      assert Accounts.delete_api_token(user, token.id) == :error
    end

    test "survive a password change", %{user: user} do
      {raw, _} = api_token_fixture(user)
      new = "a brand new long password"

      {:ok, _} =
        Accounts.update_user_password(user, %{"password" => new, "password_confirmation" => new})

      assert {:ok, _} = Accounts.fetch_api_token(raw)
    end

    test "end when setup is completed again (account recovery)", %{user: user} do
      {raw, _} = api_token_fixture(user)
      {:ok, _, link} = Accounts.create_setup_link(user.email)
      secret = Accounts.SecondFactor.new_totp_secret()

      {:ok, _} =
        Accounts.complete_setup(user, link, secret, %{
          "password" => valid_user_password(),
          "password_confirmation" => valid_user_password(),
          "code" => NimbleTOTP.verification_code(secret)
        })

      assert Accounts.fetch_api_token(raw) == :error
    end
  end
end
