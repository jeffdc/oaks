defmodule Oaks.Accounts.SecretBoxTest do
  use ExUnit.Case, async: true

  alias Oaks.Accounts.SecretBox

  test "round-trips a secret for the same context" do
    box = SecretBox.encrypt("a secret", "totp:1")
    refute box =~ "a secret"
    assert SecretBox.decrypt(box, "totp:1") == {:ok, "a secret"}
  end

  test "uses a fresh IV each time" do
    refute SecretBox.encrypt("a secret", "totp:1") == SecretBox.encrypt("a secret", "totp:1")
  end

  test "refuses another context, a tampered box and rubbish" do
    box = SecretBox.encrypt("a secret", "totp:1")
    <<head::binary-size(byte_size(box) - 1), last>> = box

    assert SecretBox.decrypt(box, "totp:2") == :error
    assert SecretBox.decrypt(head <> <<Bitwise.bxor(last, 1)>>, "totp:1") == :error
    assert SecretBox.decrypt("short", "totp:1") == :error
  end

  test "decode_key!/1 needs 32 bytes of base64" do
    assert byte_size(SecretBox.decode_key!(Base.encode64(:crypto.strong_rand_bytes(32)))) == 32
    assert_raise ArgumentError, fn -> SecretBox.decode_key!(Base.encode64("too short")) end
    assert_raise ArgumentError, fn -> SecretBox.decode_key!("not base64!") end
  end
end
