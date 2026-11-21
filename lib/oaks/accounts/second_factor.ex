defmodule Oaks.Accounts.SecondFactor do
  @moduledoc """
  The second login factor: TOTP codes (RFC 6238, via NimbleTOTP) and
  single-use recovery codes.

  TOTP codes rotate every 30 seconds. A code from the period before or after
  the current one is also accepted, for clock drift. Once a code is used,
  it and every earlier code are refused (`:since`), so a code can't be
  replayed.

  Recovery codes are 16 random base32 characters (80 bits) shown as four
  groups of four. They are random, not chosen, so a SHA-256 hash is enough to
  store them; a slow password hash isn't needed.
  """

  @issuer "Oak Compendium"
  @period 30
  @recovery_code_count 10

  @doc "A new random TOTP secret (20 bytes)."
  @spec new_totp_secret() :: binary()
  def new_totp_secret, do: NimbleTOTP.secret()

  @doc "The `otpauth://` URI an authenticator app reads, from a QR code or by hand."
  @spec otpauth_uri(binary(), String.t()) :: String.t()
  def otpauth_uri(secret, email) do
    NimbleTOTP.otpauth_uri("#{@issuer}:#{email}", secret, issuer: @issuer)
  end

  @doc "The secret as base32, for typing into an authenticator app."
  @spec display_secret(binary()) :: String.t()
  def display_secret(secret) do
    secret
    |> Base.encode32(padding: false)
    |> String.graphemes()
    |> Enum.chunk_every(4)
    |> Enum.map_join(" ", &Enum.join/1)
  end

  @doc "An SVG QR code for `uri`."
  @spec qr_svg(String.t()) :: String.t()
  def qr_svg(uri) do
    uri
    |> EQRCode.encode()
    |> EQRCode.svg(width: 220)
  end

  @doc """
  Checks a TOTP `code` against `secret`.

  `since` is when the last accepted code was used (or nil). Returns
  `{:ok, used_at}`, the time to record as the new `since`, or `:error`.
  """
  @spec verify_totp(binary(), String.t(), DateTime.t() | nil, integer()) ::
          {:ok, DateTime.t()} | :error
  def verify_totp(secret, code, since, now \\ System.os_time(:second)) do
    code = normalize(code)

    Enum.find_value([now, now - @period, now + @period], :error, fn time ->
      if NimbleTOTP.valid?(secret, code, time: time, since: since),
        do: {:ok, DateTime.from_unix!(time)}
    end)
  end

  @doc "Whether `code` looks like a TOTP code (six digits) rather than a recovery code."
  @spec totp_code?(String.t()) :: boolean()
  def totp_code?(code), do: normalize(code) =~ ~r/^\d{6}$/

  @doc "A fresh set of recovery codes, as shown to the user."
  @spec new_recovery_codes() :: [String.t()]
  def new_recovery_codes do
    for _ <- 1..@recovery_code_count do
      10
      |> :crypto.strong_rand_bytes()
      |> Base.encode32(padding: false)
      |> String.graphemes()
      |> Enum.chunk_every(4)
      |> Enum.map_join("-", &Enum.join/1)
    end
  end

  @doc "The stored form of a recovery code, ignoring case, spaces and dashes."
  @spec hash_recovery_code(String.t()) :: binary()
  def hash_recovery_code(code) do
    :crypto.hash(:sha256, code |> normalize() |> String.upcase())
  end

  defp normalize(code), do: String.replace(code, ~r/[\s-]/, "")
end
