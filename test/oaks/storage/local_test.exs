defmodule Oaks.Storage.LocalTest do
  # Points the store's root at this test's directory (application env).
  use ExUnit.Case, async: false

  import Mox

  alias Oaks.Storage.Images
  alias Oaks.Storage.Local
  alias Oaks.Storage.MockAdapter

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    config = Application.fetch_env!(:oaks, :images)
    Application.put_env(:oaks, :images, Keyword.put(config, :local_root, tmp_dir))
    on_exit(fn -> Application.put_env(:oaks, :images, config) end)

    stub_with(MockAdapter, Local)
    :ok
  end

  test "stores, lists and deletes files under its root", %{tmp_dir: tmp_dir} do
    {:ok, path} = Images.original_path(5, "jpg")

    assert :ok = Images.put(path, "original bytes", "image/jpeg")
    assert File.read!(Path.join(tmp_dir, path)) == "original bytes"
    assert Local.root() == tmp_dir

    assert {:ok, [^path]} = Images.list("species/5/")
    assert {:ok, []} = Images.list("species/6/")

    assert :ok = Images.delete(path)
    refute File.exists?(Path.join(tmp_dir, path))
    assert {:ok, []} = Images.list("species/5/")
  end

  test "putting a path again replaces it" do
    assert :ok = Images.put("species/1/a_original.png", "one", "image/png")
    assert :ok = Images.put("species/1/a_original.png", "two", "image/png")

    assert {:ok, ["species/1/a_original.png"]} = Images.list("")
    assert File.read!(Path.join(Local.root(), "species/1/a_original.png")) == "two"
  end

  test "deleting a missing file succeeds, so a cleanup can be repeated" do
    paths = Images.all_paths("species/9/9_1_ab_original.jpg")
    :ok = Images.put(hd(paths), "x", "image/jpeg")

    assert :ok = Images.delete(paths)
    assert :ok = Images.delete(paths)
  end

  test "list/1 returns every file under a prefix, in order" do
    for path <- ~w(species/2/b_small.jpg species/2/a_original.jpg species/20/c_original.jpg) do
      :ok = Images.put(path, "x", "image/jpeg")
    end

    assert {:ok, ["species/2/a_original.jpg", "species/2/b_small.jpg"]} =
             Images.list("species/2/")

    assert {:ok, [_, _, _]} = Images.list("species/")
  end

  test "an invalidation completes at once" do
    assert {:ok, id} = Images.invalidate(["species/1/a_original.jpg"], "cleanup-1")
    assert {:ok, :completed} = Images.invalidation_status(id)
  end
end
