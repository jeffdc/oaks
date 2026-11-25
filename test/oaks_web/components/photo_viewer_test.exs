defmodule OaksWeb.PhotoViewerTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias Oaks.Images.Image
  alias OaksWeb.DesignComponents
  alias OaksWeb.PhotoViewer

  defp photo(n, attrs \\ %{}) do
    Map.merge(
      %{
        src: "/p#{n}_medium.jpg",
        thumb: "/p#{n}_small.jpg",
        full: "/p#{n}_large.jpg",
        creator: "janedoe - Jane Doe",
        license: "CC-BY-NC",
        licenselink: "https://creativecommons.org/licenses/by-nc/4.0/",
        sourcelink: "https://www.inaturalist.org/observations/#{n}",
        source_label: "iNaturalist observation"
      },
      attrs
    )
  end

  defp viewer(photos) do
    assigns = %{photos: photos}

    rendered_to_string(~H"""
    <PhotoViewer.photo_viewer id="pv" label="Quercus shumardii" photos={@photos} />
    """)
  end

  defp parse(html), do: LazyHTML.from_fragment(html)
  defp count(doc, selector), do: doc |> LazyHTML.query(selector) |> Enum.count()

  defp text(doc, selector),
    do: doc |> LazyHTML.query(selector) |> LazyHTML.text() |> String.trim()

  describe "photo_viewer/1 with no photos" do
    test "reads No photos yet., with no hook, rail or dialogs" do
      doc = parse(viewer([]))

      assert text(doc, ".pv-empty") == "No photos yet."
      assert count(doc, "[phx-hook]") == 0
      assert count(doc, ".pv-rail") == 0
      assert count(doc, "dialog") == 0
    end
  end

  describe "photo_viewer/1 with one photo" do
    test "shows the photo and its credit, with no rail or count" do
      doc = parse(viewer([photo(1, %{caption: "Bark of a mature tree"})]))

      assert count(doc, "[phx-hook=PhotoViewer][phx-update=ignore][data-count='1']") == 1
      assert count(doc, "[data-slide]") == 1
      assert count(doc, "[data-slide='0']:not([hidden]) img[src='/p1_medium.jpg']") == 1
      assert text(doc, "[data-slide='0'] .pv-cap") == "Bark of a mature tree"
      assert count(doc, ".pv-rail") == 0
      assert count(doc, "[data-counter]") == 0
      assert count(doc, "[data-lightbox] [data-prev]") == 0
      assert count(doc, "[data-open-details]") == 1
      assert count(doc, ".pv-empty") == 0
    end
  end

  describe "photo_viewer/1 with many photos" do
    setup do
      %{doc: parse(viewer(Enum.map(1..12, &photo/1)))}
    end

    test "renders every photo's slide, full-size figure and details, the first shown", %{doc: doc} do
      assert count(doc, "[phx-hook=PhotoViewer][data-count='12']") == 1

      for attr <- ~w(data-slide data-full data-info) do
        assert count(doc, "[#{attr}]") == 12
        assert count(doc, "[#{attr}]:not([hidden])") == 1
        assert count(doc, "[#{attr}='0']:not([hidden])") == 1
      end
    end

    test "uses each size where it belongs", %{doc: doc} do
      assert count(doc, "[data-slide='4'] [data-open] img[src='/p5_medium.jpg']") == 1
      assert count(doc, "[data-go='4'] img[src='/p5_small.jpg']") == 1
      # The full size is loaded only when it is shown.
      assert count(doc, "[data-full='4'] img[data-src='/p5_large.jpg']:not([src])") == 1
    end

    test "has the rail the hook drives: step buttons, thumbnails and the count", %{doc: doc} do
      assert count(doc, ".pv-rail:not([data-fits])") == 1
      assert count(doc, ".pv-rail [data-page='-1'][aria-label='Earlier photos']") == 1
      assert count(doc, ".pv-rail [data-page='1'][aria-label='Later photos']") == 1
      assert count(doc, "[data-thumbs] [data-go]") == 12
      assert count(doc, "[data-go='0'][aria-current='true']") == 1
      assert count(doc, "[data-go][aria-current='false']") == 11
      assert count(doc, "[data-go='11'][aria-label='Photo 12 of 12']") == 1

      assert doc |> LazyHTML.query("[data-counter]") |> Enum.map(&LazyHTML.text/1) == [
               "1 / 12",
               "1 / 12"
             ]
    end

    test "has the full-size view and the details dialog", %{doc: doc} do
      assert count(doc, "dialog[data-lightbox] [data-close]") == 1
      assert count(doc, "dialog[data-lightbox] [data-prev]") == 1
      assert count(doc, "dialog[data-lightbox] [data-next]") == 1
      assert count(doc, "dialog[data-details] [data-close]") == 1
      assert text(doc, "dialog[data-details] h2") == "Photo details"
      assert count(doc, "[data-slide] [data-open][data-stage]") == 12
      assert count(doc, "[data-lightbox] [data-stage]") == 1
    end

    test "labels the photos" do
      doc = parse(viewer([photo(1), photo(2, %{alt: "Acorn and cap"})]))

      assert count(doc, "[role=region][aria-label='Photos of Quercus shumardii']") == 1
      assert count(doc, "[data-slide='0'] img[alt='Photo 1 of Quercus shumardii']") == 1
      assert count(doc, "[data-slide='1'] img[alt='Acorn and cap']") == 1
    end

    test "a short set fits the rail without step buttons" do
      doc = parse(viewer(Enum.map(1..5, &photo/1)))
      assert count(doc, ".pv-rail[data-fits]") == 1
    end
  end

  describe "photo_viewer/1 credit and details" do
    test "credits the creator, the license (linked) and the source" do
      doc = parse(viewer([photo(1)]))
      credit = LazyHTML.query(doc, "[data-slide='0'] .pv-credit")

      assert text(credit, "b") == "janedoe - Jane Doe"

      assert count(credit, "a[href='https://creativecommons.org/licenses/by-nc/4.0/']") == 1

      assert text(credit, "a[href='https://www.inaturalist.org/observations/1']") =~
               "iNaturalist observation"

      refute LazyHTML.text(credit) =~ "©"

      details = doc |> LazyHTML.query("[data-info='0'] dt") |> Enum.map(&LazyHTML.text/1)
      assert details == ["Creator", "License", "Source"]
    end

    test "an all-rights-reserved photo marks the creator © and sets the license on its own line" do
      license = "All rights reserved, used with the creator's permission"
      doc = parse(viewer([photo(1, %{license: license, licenselink: nil, reserved: true})]))
      credit = LazyHTML.query(doc, "[data-slide='0'] .pv-credit")

      assert LazyHTML.text(credit) =~ "© janedoe - Jane Doe"
      assert text(credit, "strong.pv-reserved") == license
    end

    test "shows the uploader and attribution in the details when given" do
      doc = parse(viewer([photo(1, %{uploader: "jeff", attribution: "Plate 4", caption: ""})]))
      details = doc |> LazyHTML.query("[data-info='0'] dt") |> Enum.map(&LazyHTML.text/1)

      assert details == ["Creator", "License", "Attribution", "Source", "Uploader"]
    end

    test "pushes no event unless asked to" do
      assert count(parse(viewer([photo(1)])), "[data-event]") == 0

      assigns = %{}

      html =
        rendered_to_string(~H"""
        <PhotoViewer.photo_viewer id="pv" label="Q" photos={[%{src: "/a.jpg"}]} on_change="moved" />
        """)

      assert count(parse(html), "[data-event='moved']") == 1
    end

    test "gives new photos a new hook element, so the viewer starts again" do
      id = fn photos ->
        parse(viewer(photos)) |> LazyHTML.query("[phx-hook]") |> LazyHTML.attribute("id")
      end

      assert id.([photo(1)]) == id.([photo(1)])
      refute id.([photo(1)]) == id.([photo(1), photo(2)])
    end
  end

  describe "species_photos/1" do
    defp image(id, attrs \\ %{}) do
      struct!(
        %Image{
          id: id,
          species_id: 1,
          path: "species/1/1_#{id}_ab_original.jpg",
          status: "ready",
          creator: "janedoe - Jane Doe",
          license: "CC-BY",
          licenselink: "https://creativecommons.org/licenses/by/4.0/",
          sourcelink: "https://www.inaturalist.org/observations/9"
        },
        attrs
      )
    end

    defp species_photos(images) do
      assigns = %{images: images}

      ~H"""
      <DesignComponents.species_photos id="species-photos" images={@images} name="Quercus alba" />
      """
      |> rendered_to_string()
      |> parse()
    end

    test "shows only ready photos, medium on the stage and small in the rail" do
      doc =
        species_photos([
          image(1),
          image(2, %{status: "pending"}),
          image(3, %{status: "failed"}),
          image(4)
        ])

      assert count(doc, ".oc-photos.pv") == 1
      assert count(doc, "[phx-hook=PhotoViewer][data-count='2']") == 1
      assert count(doc, "[data-slide='0'] img[src$='/species/1/1_1_ab_medium.jpg']") == 1
      assert count(doc, "[data-go='1'] img[src$='/species/1/1_4_ab_small.jpg']") == 1
      assert count(doc, "[data-full='0'] img[data-src$='/species/1/1_1_ab_large.jpg']") == 1
      refute LazyHTML.to_html(doc) =~ "1_2_ab"
      refute LazyHTML.to_html(doc) =~ "1_3_ab"
    end

    test "credits the creator, the license and the iNaturalist observation" do
      credit = species_photos([image(1)]) |> LazyHTML.query("[data-slide='0'] .pv-credit")

      assert text(credit, "b") == "janedoe - Jane Doe"
      assert text(credit, "a[href='https://creativecommons.org/licenses/by/4.0/']") == "CC-BY"

      assert text(credit, "a[href='https://www.inaturalist.org/observations/9']") =~
               "iNaturalist observation"
    end

    test "says an All Rights Reserved photo is used with the creator's permission" do
      doc =
        species_photos([
          image(1, %{
            license: "All Rights Reserved",
            licenselink: nil,
            permission_confirmed_by: "dev@localhost"
          })
        ])

      assert text(doc, "[data-slide='0'] .pv-reserved") ==
               "All rights reserved, used with the creator's permission"

      assert text(doc, "[data-slide='0'] .pv-credit") =~ "© janedoe - Jane Doe"
    end

    test "never shows who uploaded or last changed a photo" do
      doc =
        species_photos([image(1, %{uploader: "ed@example.com", lastchangedby: "ed@example.com"})])

      refute LazyHTML.to_html(doc) =~ "ed@example.com"
    end

    test "with no ready photos reads No photos yet." do
      doc = species_photos([image(1, %{status: "pending"})])

      assert text(doc, ".pv-empty") == "No photos yet."
      assert count(doc, "[phx-hook]") == 0
    end
  end
end
