defmodule Oaks.LicensesTest do
  use ExUnit.Case, async: true

  alias Oaks.Images.Attribution
  alias Oaks.Licenses

  doctest Oaks.Licenses
  doctest Oaks.Images.Attribution

  test "only licenses that let the site show a photo are importable" do
    for license <- Licenses.all() -- ["All Rights Reserved"] do
      assert Licenses.importable?(license), license
    end

    refute Licenses.importable?("All Rights Reserved")
    refute Licenses.importable?(nil)
    refute Licenses.importable?("CC-BY-4")
  end

  test "only All Rights Reserved needs the creator's permission" do
    assert Licenses.needs_permission?("All Rights Reserved")

    for license <- [nil, "CC-BY-4" | Licenses.all() -- ["All Rights Reserved"]] do
      refute Licenses.needs_permission?(license), inspect(license)
    end
  end

  test "url/1 gives each Creative Commons license's URL" do
    assert Licenses.url("CC-BY-NC") == "https://creativecommons.org/licenses/by-nc/4.0/"
    assert Licenses.url("Public Domain / CC0") =~ "publicdomain/zero"
    assert Licenses.url("nope") == nil
  end

  describe "Attribution.attributed?/1" do
    test "needs a valid license and, except for CC0, a creator" do
      assert Attribution.attributed?(%{license: "CC-BY", creator: "janedoe"})
      assert Attribution.attributed?(%{license: "Public Domain / CC0", creator: nil})
      refute Attribution.attributed?(%{license: "CC-BY", creator: " "})
      refute Attribution.attributed?(%{license: "CC-BY", creator: nil})
      refute Attribution.attributed?(%{license: nil, creator: "janedoe"})
    end

    test "takes All Rights Reserved only with the creator's permission recorded, and a creator" do
      arr = %{license: "All Rights Reserved", creator: "janedoe"}

      refute Attribution.attributed?(arr)
      refute Attribution.attributed?(Map.put(arr, :permission_confirmed_by, " "))
      assert Attribution.attributed?(Map.put(arr, :permission_confirmed_by, "ed@example.com"))

      refute Attribution.attributed?(
               %{
                 arr
                 | creator: nil
               }
               |> Map.put(:permission_confirmed_by, "ed@example.com")
             )
    end
  end
end
