defmodule Oaks.Accounts.SecretBox do
  @moduledoc """
  Encrypts login secrets (TOTP secrets) at rest with AES-256-GCM.

  The key is `:login_encryption_key`: 32 bytes, base64-encoded, from the
  `LOGIN_ENCRYPTION_KEY` secret in production. A copy of the database alone
  (a Litestream backup, `make download-db`) holds only ciphertext.

  `context` is bound in as associated data (for example `"totp:42"` for user
  42), so a ciphertext copied onto another row or used for another purpose
  fails to decrypt.

  Stored form: `<<1, iv::binary-12, tag::binary-16, ciphertext::binary>>`;
  the leading version byte leaves room to change the scheme.
  """

  @version 1
  @iv_size 12
  @tag_size 16

  @doc "Encrypts `plaintext` for `context`."
  @spec encrypt(binary(), String.t()) :: binary()
  def encrypt(plaintext, context) when is_binary(plaintext) and is_binary(context) do
    iv = :crypto.strong_rand_bytes(@iv_size)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, key(), iv, plaintext, context, @tag_size, true)

    <<@version, iv::binary, tag::binary, ciphertext::binary>>
  end

  @doc "Decrypts what `encrypt/2` returned for the same `context`."
  @spec decrypt(binary(), String.t()) :: {:ok, binary()} | :error
  def decrypt(
        <<@version, iv::binary-size(@iv_size), tag::binary-size(@tag_size), ciphertext::binary>>,
        context
      )
      when is_binary(context) do
    case :crypto.crypto_one_time_aead(:aes_256_gcm, key(), iv, ciphertext, context, tag, false) do
      plaintext when is_binary(plaintext) -> {:ok, plaintext}
      :error -> :error
    end
  end

  def decrypt(_box, _context), do: :error

  @doc """
  Decodes and checks a base64 key. Used by `config/runtime.exs` so a bad
  `LOGIN_ENCRYPTION_KEY` stops the release at boot rather than at first login.
  """
  @spec decode_key!(String.t()) :: binary()
  def decode_key!(encoded) when is_binary(encoded) do
    case Base.decode64(String.trim(encoded)) do
      {:ok, <<_::binary-32>> = key} -> key
      _ -> raise ArgumentError, "the login encryption key must be 32 bytes, base64-encoded"
    end
  end

  defp key do
    :oaks
    |> Application.fetch_env!(:login_encryption_key)
    |> decode_key!()
  end
end
