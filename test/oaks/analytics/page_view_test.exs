defmodule Oaks.Analytics.PageViewTest do
  @moduledoc """
  Tests for the PageView schema's changeset validations.

  These tests only exercise the changeset, not the database, so they don't
  depend on the page_views table existing.
  """
  use Oaks.DataCase

  alias Oaks.Analytics.PageView

  @valid_visitor_hash String.duplicate("a", 64)

  defp valid_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        path: "/species/quercus-alba",
        status: 200,
        referrer_host: "google.com",
        browser: "Chrome",
        device_type: "desktop",
        visitor_hash: @valid_visitor_hash
      },
      overrides
    )
  end

  describe "changeset/2" do
    test "is valid with full attrs" do
      changeset = PageView.changeset(%PageView{}, valid_attrs())
      assert changeset.valid?
    end

    test "is valid with nil referrer_host, browser, device_type" do
      attrs =
        valid_attrs(%{
          referrer_host: nil,
          browser: nil,
          device_type: nil
        })

      changeset = PageView.changeset(%PageView{}, attrs)
      assert changeset.valid?
    end

    test "is invalid when path is missing" do
      attrs = valid_attrs() |> Map.delete(:path)
      changeset = PageView.changeset(%PageView{}, attrs)
      refute changeset.valid?
      assert %{path: ["can't be blank"]} = errors_on(changeset)
    end

    test "is invalid when status is missing" do
      attrs = valid_attrs() |> Map.delete(:status)
      changeset = PageView.changeset(%PageView{}, attrs)
      refute changeset.valid?
      assert %{status: ["can't be blank"]} = errors_on(changeset)
    end

    test "is invalid when visitor_hash is missing" do
      attrs = valid_attrs() |> Map.delete(:visitor_hash)
      changeset = PageView.changeset(%PageView{}, attrs)
      refute changeset.valid?
      assert %{visitor_hash: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects oversize path" do
      oversize_path = "/" <> String.duplicate("a", 2000)
      attrs = valid_attrs(%{path: oversize_path})
      changeset = PageView.changeset(%PageView{}, attrs)
      refute changeset.valid?
      assert Map.has_key?(errors_on(changeset), :path)
    end

    test "rejects wrong-length visitor_hash (63 chars)" do
      attrs = valid_attrs(%{visitor_hash: String.duplicate("a", 63)})
      changeset = PageView.changeset(%PageView{}, attrs)
      refute changeset.valid?
      assert Map.has_key?(errors_on(changeset), :visitor_hash)
    end
  end
end
