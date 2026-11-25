defmodule Oaks.Storage.ImagesTest do
  use ExUnit.Case, async: false

  import Mox

  alias Oaks.Storage.Images
  alias Oaks.Storage.MockAdapter

  setup :verify_on_exit!

  describe "original_path/2" do
    test "is unique per call, under the species, and keeps the extension lower case" do
      {:ok, a} = Images.original_path(12, ".JPG")
      {:ok, b} = Images.original_path(12, "jpg")

      assert a != b
      assert a =~ ~r"\Aspecies/12/12_\d+_[0-9a-f]{10}_original\.jpg\z"
      assert b =~ ~r"\Aspecies/12/12_\d+_[0-9a-f]{10}_original\.jpg\z"
    end

    test "refuses file types the variants can't be made in" do
      assert {:error, {:unsupported_extension, "gif"}} = Images.original_path(12, "gif")
      assert {:error, {:unsupported_extension, "../x"}} = Images.original_path(12, "../x")
    end
  end

  describe "paths and URLs" do
    @original "species/3/3_1764000000000_0a1b2c3d4e_original.jpg"

    test "variant_path/2 swaps the size into the file name" do
      assert Images.variant_path(@original, :original) == @original

      assert Images.variant_path(@original, :medium) ==
               "species/3/3_1764000000000_0a1b2c3d4e_medium.jpg"
    end

    test "variant_path/2 only touches the file name's suffix" do
      path = "species/3/3_1_original_original.png"
      assert Images.variant_path(path, :small) == "species/3/3_1_original_small.png"
    end

    test "variant_path/2 refuses a path that isn't an original's" do
      assert_raise ArgumentError, fn -> Images.variant_path("species/3/3_1_small.jpg", :large) end
    end

    test "all_paths/1 lists the original and its four variants" do
      assert Images.all_paths(@original) == [
               @original,
               "species/3/3_1764000000000_0a1b2c3d4e_small.jpg",
               "species/3/3_1764000000000_0a1b2c3d4e_medium.jpg",
               "species/3/3_1764000000000_0a1b2c3d4e_large.jpg",
               "species/3/3_1764000000000_0a1b2c3d4e_xlarge.jpg"
             ]
    end

    test "public_url/1 and variant_url/2 are on the configured CDN" do
      assert Images.public_url(@original) == "https://images.test/#{@original}"
      assert Images.public_url("/" <> @original) == "https://images.test/#{@original}"

      assert Images.variant_url(@original, :small) ==
               "https://images.test/species/3/3_1764000000000_0a1b2c3d4e_small.jpg"
    end

    test "content_type/1 follows the extension" do
      assert Images.content_type("a/b_original.jpg") == "image/jpeg"
      assert Images.content_type("a/b_original.JPEG") == "image/jpeg"
      assert Images.content_type("a/b_small.png") == "image/png"
      assert Images.content_type("a/b_small.webp") == "image/webp"
    end
  end

  describe "storage calls" do
    test "put/3 passes the file to the adapter, and its failure back" do
      expect(MockAdapter, :put, fn "species/1/x_original.jpg", "bytes", "image/jpeg" -> :ok end)
      assert :ok = Images.put("species/1/x_original.jpg", "bytes", "image/jpeg")

      expect(MockAdapter, :put, fn _, _, _ -> {:error, :timeout} end)
      assert {:error, :timeout} = Images.put("species/1/x_original.jpg", "bytes", "image/jpeg")
    end

    test "paths that could leave the store's root never reach the adapter" do
      for path <- ["../etc/passwd", "species/../../x", "/abs/path", "a//b", "a/./b", "a b", ""] do
        assert {:error, {:invalid_path, ^path}} = Images.put(path, "x", "image/jpeg")
        assert {:error, {:invalid_path, ^path}} = Images.delete(path)
      end

      assert {:error, {:invalid_path, "../"}} = Images.list("../")
      assert {:error, {:invalid_path, "/x"}} = Images.invalidate(["/x"], "ref")
    end

    test "delete/1 deletes every path in order" do
      paths = Images.all_paths("species/3/3_1_ab_original.jpg")
      test = self()

      expect(MockAdapter, :delete, 5, fn path ->
        send(test, {:deleted, path})
        :ok
      end)

      assert :ok = Images.delete(paths)

      for path <- paths, do: assert_received({:deleted, ^path})
    end

    test "delete/1 stops at the first failure and names its path" do
      expect(MockAdapter, :delete, fn "a/1_original.jpg" -> :ok end)
      expect(MockAdapter, :delete, fn "a/1_small.jpg" -> {:error, :access_denied} end)

      assert {:error, {"a/1_small.jpg", :access_denied}} =
               Images.delete(["a/1_original.jpg", "a/1_small.jpg", "a/1_medium.jpg"])
    end

    test "list/1 takes a folder prefix" do
      expect(MockAdapter, :list, fn "species/3/" -> {:ok, ["species/3/a.jpg"]} end)
      assert {:ok, ["species/3/a.jpg"]} = Images.list("species/3/")
    end

    test "invalidate/2 and invalidation_status/1 pass through the adapter" do
      expect(MockAdapter, :create_invalidation, fn ["a/1.jpg"], "cleanup-7" -> {:ok, "I1"} end)
      expect(MockAdapter, :invalidation_status, fn "I1" -> {:ok, :in_progress} end)
      expect(MockAdapter, :invalidation_status, fn "I1" -> {:error, :throttled} end)

      assert {:ok, "I1"} = Images.invalidate(["a/1.jpg"], "cleanup-7")
      assert {:ok, :in_progress} = Images.invalidation_status("I1")
      assert {:error, :throttled} = Images.invalidation_status("I1")
    end
  end
end
