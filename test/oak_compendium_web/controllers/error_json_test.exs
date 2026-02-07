defmodule OakCompendiumWeb.ErrorJSONTest do
  use OakCompendiumWeb.ConnCase

  test "renders 404" do
    assert OakCompendiumWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert OakCompendiumWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
