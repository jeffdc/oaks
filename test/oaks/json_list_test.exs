defmodule Oaks.JsonListTest do
  use ExUnit.Case

  alias Oaks.JsonList

  doctest Oaks.JsonList

  describe "normalize/2" do
    test "turns comma-separated names into a JSON array" do
      assert JsonList.normalize("× bebbiana, ×jackiana") == {:ok, ~s(["× bebbiana","×jackiana"])}
    end

    test "re-encodes JSON arrays and collapses stray whitespace" do
      assert JsonList.normalize(~s(["eastern white \\n        oak", " "])) ==
               {:ok, ~s(["eastern white oak"])}
    end

    test "clears blank input to nil" do
      for blank <- ["", "  ", "null", "[]", ~s([""]), ", ,"] do
        assert JsonList.normalize(blank) == {:ok, nil}
      end
    end

    test "rejects invalid JSON" do
      assert {:error, _} = JsonList.normalize(~s(["alba",))
    end

    test "rejects entries that are not names" do
      assert {:error, _} = JsonList.normalize("[1]")
      assert {:error, _} = JsonList.normalize(~s([{"name": "x"}]))
      assert {:error, _} = JsonList.normalize(~s([["alba"]]))
    end

    test "accepts name objects only when allowed" do
      json = ~s([{"name":"maxima","author":"Ashe"}])
      assert {:ok, normalized} = JsonList.normalize(json, allow_objects: true)
      assert Jason.decode!(normalized) == [%{"name" => "maxima", "author" => "Ashe"}]
      assert {:error, _} = JsonList.normalize(~s([{"author":"Ashe"}]), allow_objects: true)
    end
  end
end
