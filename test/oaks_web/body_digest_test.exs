defmodule OaksWeb.BodyDigestTest do
  use ExUnit.Case

  alias OaksWeb.BodyDigest

  @path "/api/private/v1/import"

  test "hashes the raw body of an import request" do
    body = ~s({"species": [ ]}\n)
    conn = Plug.Test.conn(:post, @path, body)

    assert {:ok, ^body, conn} = BodyDigest.read_body(conn, [])
    assert conn.private.body_sha256 == :crypto.hash(:sha256, body)
  end

  test "carries the hash across a body read in parts" do
    conn = Plug.Test.conn(:post, @path, "abcdefgh")
    opts = [length: 3, read_length: 3]

    assert {:more, "abc", conn} = BodyDigest.read_body(conn, opts)
    refute Map.has_key?(conn.private, :body_sha256)
    assert {:more, "def", conn} = BodyDigest.read_body(conn, opts)
    assert {:ok, "gh", conn} = BodyDigest.read_body(conn, opts)

    assert conn.private.body_sha256 == :crypto.hash(:sha256, "abcdefgh")
  end

  test "reads other requests without hashing" do
    conn = Plug.Test.conn(:post, "/api/private/v1/token", "abc")

    assert {:ok, "abc", conn} = BodyDigest.read_body(conn, [])
    refute Map.has_key?(conn.private, :body_sha256)
  end
end
