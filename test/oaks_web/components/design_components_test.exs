defmodule OaksWeb.DesignComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias OaksWeb.DesignComponents

  describe "taxonomy_band/1" do
    test "links every rank, sets rank words roman and marks the current taxon" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <DesignComponents.taxonomy_band>
          <:rank navigate="/taxonomy"><i>Quercus</i></:rank>
          <:rank navigate="/taxonomy/Quercus/Lobatae" rank="sect."><i>Lobatae</i></:rank>
          <:rank href="/species/shumardii" rank="complex" rank_after><i>shumardii</i></:rank>
          <:current><i>Q. shumardii</i></:current>
        </DesignComponents.taxonomy_band>
        """)

      assert html =~ ~s(class="oc-band)
      assert html =~ ~s(aria-label="Taxonomy")
      assert html =~ ~s(href="/taxonomy/Quercus/Lobatae")
      assert html =~ ~s(data-phx-link="redirect")
      assert html =~ ~r{<span class="oc-band-rk">sect\.</span>\s*<i>Lobatae</i>}
      assert html =~ ~r{<i>shumardii</i>\s*<span class="oc-band-rk">complex</span>}
      assert html =~ ~r{<span aria-current="page"><i>Q\. shumardii</i></span>}
      refute html =~ "<details"
    end

    test "adds the siblings menu when given" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <DesignComponents.taxonomy_band id="band">
          <:current><i>Q. shumardii</i></:current>
          <:siblings label="Coccineae · 7 species">
            <li><a href="/species/rubra">Q. rubra</a></li>
          </:siblings>
        </DesignComponents.taxonomy_band>
        """)

      assert html =~ ~s(id="band-siblings")
      assert html =~ "<summary>Coccineae · 7 species</summary>"
      assert html =~ ~s(<ul class="oc-band-siblings">)
      assert html =~ "phx-click-away"
    end
  end

  test "section_heading/1 renders the label and an optional note" do
    html =
      render_component(&DesignComponents.section_heading/1,
        id: "field-marks",
        inner_block: [%{inner_block: fn _, _ -> "Field marks" end}],
        note: [%{inner_block: fn _, _ -> "3 traits" end}]
      )

    assert html =~ ~r{<h2 id="field-marks" class="oc-section-heading}
    assert html =~ "Field marks"
    assert html =~ ~s(<small class="oc-section-heading-note">3 traits</small>)

    html =
      render_component(&DesignComponents.section_heading/1,
        level: "h3",
        inner_block: [%{inner_block: fn _, _ -> "Range" end}]
      )

    assert html =~ "<h3"
    refute html =~ "<small"
  end

  describe "source_mark/1" do
    test "links to the source" do
      html =
        render_component(&DesignComponents.source_mark/1,
          href: "https://www.inaturalist.org/observations/190127456",
          inner_block: [%{inner_block: fn _, _ -> "i465271504" end}]
        )

      assert html =~ ~r{<a [^>]*class="oc-src}
      assert html =~ ~s(href="https://www.inaturalist.org/observations/190127456")
      assert html =~ "i465271504"
    end

    test "is plain text in the same style without a link" do
      html =
        render_component(&DesignComponents.source_mark/1,
          title: "Comes with the facts model",
          inner_block: [%{inner_block: fn _, _ -> "counts" end}]
        )

      assert html =~
               ~r{<span class="oc-src[^"]*" title="Comes with the facts model">counts</span>}

      refute html =~ "<a"
    end
  end

  describe "standing_mark/1" do
    for {standing, shape} <- [
          {"agree", ~s(<path d="M4 7.2)},
          {"differs", "<rect"},
          {"open", "stroke-dasharray"}
        ] do
      test "draws the #{standing} mark beside its label" do
        html =
          render_component(&DesignComponents.standing_mark/1,
            standing: unquote(standing),
            inner_block: [%{inner_block: fn _, _ -> "Sibley differs on size" end}]
          )

        assert html =~ ~s(data-standing="#{unquote(standing)}")
        assert html =~ unquote(shape)
        assert html =~ ~s(aria-hidden="true")
        assert html =~ "Sibley differs on size"
      end
    end
  end

  test "status_tag/1 renders an outlined stamp with its full name as a title" do
    html =
      render_component(&DesignComponents.status_tag/1,
        title: "IUCN Red List: Least Concern",
        inner_block: [%{inner_block: fn _, _ -> "IUCN LC" end}]
      )

    assert html =~
             ~r{<span class="oc-status\s*" title="IUCN Red List: Least Concern">IUCN LC</span>}
  end

  describe "iucn_status/1" do
    for {code, category} <- [
          {"EX", "Extinct"},
          {"EW", "Extinct in the Wild"},
          {"CR", "Critically Endangered"},
          {"EN", "Endangered"},
          {"VU", "Vulnerable"},
          {"NT", "Near Threatened"},
          {"LC", "Least Concern"},
          {"DD", "Data Deficient"},
          {"NE", "Not Evaluated"}
        ] do
      test "#{code} is the stamp in its Red List colour, with #{category} spelled out" do
        html = render_component(&DesignComponents.iucn_status/1, code: unquote(code))
        class = "oc-iucn-" <> String.downcase(unquote(code))

        assert html =~ ~r{class="oc-status oc-iucn #{class}"}
        assert html =~ ~s(title="IUCN Red List: #{unquote(category)}")
        assert html =~ ~r{>\s*IUCN #{unquote(code)}<}
        assert html =~ ~s(<span class="sr-only">: #{unquote(category)}</span>)
        assert DesignComponents.iucn_category(unquote(code)) == unquote(category)
      end
    end

    test "without the prefix, IUCN is for screen readers only" do
      html = render_component(&DesignComponents.iucn_status/1, code: "VU", prefix: false)

      assert html =~ ~r{>\s*<span class="sr-only">IUCN </span>VU<}
      refute html =~ "false"
      assert html =~ ~s(<span class="sr-only">: Vulnerable</span>)
    end

    test "a code that isn't a Red List category is the plain stamp" do
      html = render_component(&DesignComponents.iucn_status/1, code: "XX")

      assert html =~ ~r{class="oc-status\s*"}
      refute html =~ "oc-iucn"
      refute html =~ "title="
      refute html =~ "sr-only"
      assert html =~ "XX"
      assert DesignComponents.iucn_category("XX") == nil
    end
  end

  describe "compare_button/1" do
    test "is a compact primary button reading Compare by default" do
      html = render_component(&DesignComponents.compare_button/1, navigate: "/species/rubra")

      assert html =~ ~s(href="/species/rubra")
      assert html =~ "oc-btn oc-btn-primary oc-btn-compact"
      assert html =~ "Compare"
    end

    test "takes its own label" do
      html =
        render_component(&DesignComponents.compare_button/1,
          patch: "/species/shumardii?vs=rubra",
          inner_block: [%{inner_block: fn _, _ -> "Compare with Q. rubra" end}]
        )

      assert html =~ ~s(data-phx-link="patch")
      assert html =~ "Compare with Q. rubra"
    end
  end

  test "other_sources/1 puts each source behind a standing-mark summary" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <DesignComponents.other_sources standing="differs" summary="Sibley differs on size">
        <:source by="Sibley Guide to Trees">large, grayish or straw-colored, and hairless</:source>
        <:source by="Oaks of the World">glabrous</:source>
      </DesignComponents.other_sources>
      """)

    assert html =~ ~s(<details class="oc-other">)
    assert html =~ ~r{<summary>.*data-standing="differs".*Sibley differs on size.*</summary>}s
    assert html =~ ~s(<span class="oc-by">Sibley Guide to Trees</span>)
    assert html =~ ~s(<span class="oc-by">Oaks of the World</span>)
  end

  test "no_statement/1 reads No statement yet" do
    html = render_component(&DesignComponents.no_statement/1, %{})
    assert html =~ ~s(<span class="oc-empty">)
    assert html =~ "No statement yet"
  end
end
