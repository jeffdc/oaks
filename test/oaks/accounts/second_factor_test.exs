defmodule Oaks.Accounts.SecondFactorTest do
  use ExUnit.Case, async: true

  alias Oaks.Accounts.SecondFactor

  @now 1_800_000_000

  setup do
    %{secret: SecondFactor.new_totp_secret()}
  end

  defp code(secret, time), do: NimbleTOTP.verification_code(secret, time: time)

  test "accepts the current code and one period either side", %{secret: secret} do
    for offset <- [-30, 0, 30] do
      assert {:ok, _} = SecondFactor.verify_totp(secret, code(secret, @now + offset), nil, @now)
    end

    assert SecondFactor.verify_totp(secret, code(secret, @now - 90), nil, @now) == :error
    assert SecondFactor.verify_totp(secret, code(secret, @now + 90), nil, @now) == :error
  end

  test "refuses a code at or before the last one used", %{secret: secret} do
    {:ok, used_at} = SecondFactor.verify_totp(secret, code(secret, @now), nil, @now)

    assert SecondFactor.verify_totp(secret, code(secret, @now), used_at, @now) == :error
    assert SecondFactor.verify_totp(secret, code(secret, @now - 30), used_at, @now) == :error
    assert {:ok, _} = SecondFactor.verify_totp(secret, code(secret, @now + 30), used_at, @now)
  end

  test "ignores spaces in a typed code", %{secret: secret} do
    <<a::binary-3, b::binary-3>> = code(secret, @now)
    assert {:ok, _} = SecondFactor.verify_totp(secret, a <> " " <> b, nil, @now)
  end

  test "tells TOTP codes from recovery codes" do
    assert SecondFactor.totp_code?("123456")
    assert SecondFactor.totp_code?("123 456")
    refute SecondFactor.totp_code?("ABCD-EFGH-IJKL-MNOP")
  end

  test "recovery codes are 10 distinct 80-bit codes, hashed ignoring case and dashes" do
    codes = SecondFactor.new_recovery_codes()
    assert length(Enum.uniq(codes)) == 10

    [code | _] = codes
    typed = code |> String.downcase() |> String.replace("-", " ")
    assert SecondFactor.hash_recovery_code(typed) == SecondFactor.hash_recovery_code(code)
  end

  test "the otpauth URI and QR code name the site and the account", %{secret: secret} do
    uri = SecondFactor.otpauth_uri(secret, "jeff@example.com")
    assert uri =~ "otpauth://totp/Oak%20Compendium:jeff@example.com"
    assert uri =~ "issuer=Oak%20Compendium"
    assert SecondFactor.qr_svg(uri) =~ "<svg"
    assert SecondFactor.display_secret(secret) =~ ~r/^[A-Z2-7]{4}( [A-Z2-7]{1,4})+$/
  end
end
