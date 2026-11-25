defmodule Oaks.Storage.VariantsTest do
  use ExUnit.Case, async: false

  import Mox

  alias Oaks.Storage.Images
  alias Oaks.Storage.Local
  alias Oaks.Storage.MockAdapter
  alias Oaks.Storage.Variants
  alias Vix.Vips.Image, as: VipsImage

  # 2400 x 1600 as stored, tagged "rotate 90° clockwise": upright it is 1600 x 2400.
  @fixture Path.expand("../../support/fixtures/images/landscape_rotated.jpg", __DIR__)

  test "makes all four sizes of a JPEG, upright, without metadata" do
    assert {:ok, variants} = Variants.generate(File.read!(@fixture), "jpg")
    assert Keyword.keys(variants) == [:small, :medium, :large, :xlarge]

    shapes =
      Map.new(variants, fn {size, data} ->
        {:ok, image} = Image.from_binary(data)
        assert {:error, %Image.Error{reason: :no_exif}} = Image.exif(image)

        assert {:ok, "jpegload_buffer"} = VipsImage.header_value(image, "vips-loader")
        {size, {Image.width(image), Image.height(image)}}
      end)

    assert shapes == %{
             small: {200, 300},
             medium: {533, 800},
             large: {800, 1200},
             xlarge: {1333, 2000}
           }
  end

  test "never enlarges a small original, and keeps PNG as PNG" do
    {:ok, image} = Image.new(500, 400, color: :green)
    {:ok, png} = Image.write(image, :memory, suffix: ".png")

    assert {:ok, variants} = Variants.generate(png, ".PNG")

    for {size, data} <- variants do
      {:ok, variant} = Image.from_binary(data)
      assert {:ok, "pngload_buffer"} = VipsImage.header_value(variant, "vips-loader")

      expected = if size == :small, do: {300, 240}, else: {500, 400}
      assert {Image.width(variant), Image.height(variant)} == expected
    end
  end

  test "fails, with no variants, on bytes that aren't an image" do
    assert {:error, _} = Variants.generate("not an image", "jpg")
  end

  test "fails on a file type it doesn't write" do
    assert {:error, {:unsupported_extension, "gif"}} =
             Variants.generate(File.read!(@fixture), "gif")
  end

  @tag :tmp_dir
  test "an original and its variants are stored and read back through Local", %{tmp_dir: dir} do
    config = Application.fetch_env!(:oaks, :images)
    Application.put_env(:oaks, :images, Keyword.put(config, :local_root, dir))
    on_exit(fn -> Application.put_env(:oaks, :images, config) end)
    stub_with(MockAdapter, Local)

    original = File.read!(@fixture)
    {:ok, path} = Images.original_path(42, "jpg")
    {:ok, variants} = Variants.generate(original, "jpg")

    :ok = Images.put(path, original, Images.content_type(path))

    for {size, data} <- variants do
      variant_path = Images.variant_path(path, size)
      :ok = Images.put(variant_path, data, Images.content_type(variant_path))
    end

    assert {:ok, stored} = Images.list("species/42/")
    assert stored == Enum.sort(Images.all_paths(path))

    for {size, _} <- variants do
      {:ok, image} = Image.open(Path.join(dir, Images.variant_path(path, size)))
      assert max(Image.width(image), Image.height(image)) == Images.variant_sizes()[size]
    end
  end
end
