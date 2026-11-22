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
      assert html =~ ~r{<span aria-current="page">\s*<i>Q\. shumardii</i>\s*</span>}
      refute html =~ "<details"
    end

    test "sets the current taxon's rank word in the band's roman" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <DesignComponents.taxonomy_band>
          <:current rank="sect."><i>Lobatae</i></:current>
        </DesignComponents.taxonomy_band>
        """)

      assert html =~
               ~r{<span aria-current="page">\s*<span class="oc-band-rk">\s*sect\.\s*</span>\s*<i>Lobatae</i>}

      html =
        rendered_to_string(~H"""
        <DesignComponents.taxonomy_band>
          <:current rank="complex" rank_after><i>coccinea</i></:current>
        </DesignComponents.taxonomy_band>
        """)

      assert html =~ ~r{<i>coccinea</i>\s*<span class="oc-band-rk">\s*complex\s*</span>}
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

  describe "sci_name/1" do
    defp sci(attrs), do: render_component(&DesignComponents.sci_name/1, attrs)

    test "sets the genus at 400 and the epithet at 600, with the author roman" do
      html = sci(name: "shumardii", author: "Buckley")

      assert html =~
               ~s(<span class="oc-sci-n"><i class="oc-sci-g">Quercus</i> <i class="oc-sci-e">shumardii</i></span> )

      assert html =~ ~s(<span class="oc-sci-a">Buckley</span></span>)
    end

    test "splits an authority stored in the name and sets it as the author" do
      html = sci(name: "shumardii var. acerifolia E.J.Palmer 1927", genus: nil)

      assert html =~
               ~s(<i class="oc-sci-e">shumardii</i> <span class="oc-sci-r">var.</span>\u00A0<i class="oc-sci-e">acerifolia</i></span> <span class="oc-sci-a">E.J.Palmer 1927</span>)

      assert sci(name: "phillyreoides Franch. non A.Gray", genus: nil) =~
               ~s(<span class="oc-sci-a">Franch. non A.Gray</span>)

      # The first word is the name, even when capitalised.
      assert sci(name: "Coccineae", rank: "subsect.") =~ ~s(<i class="oc-sci-e">Coccineae</i>)
      refute sci(name: "Coccineae", rank: "subsect.") =~ "oc-sci-a"

      # A given author wins over the stored one.
      assert sci(name: "candida Steud.", author: "Steudel") =~
               ~s(<span class="oc-sci-a">Steudel</span>)
    end

    test "sets the size by the name's role" do
      assert sci(name: "alba", size: "display") =~ ~s(class="oc-sci oc-sci-display)
      assert sci(name: "alba", size: "headline") =~ ~s(class="oc-sci oc-sci-headline)
      assert sci(name: "alba", size: "title") =~ ~s(class="oc-sci oc-sci-title)
      refute sci(name: "alba") =~ "oc-sci-display"
    end

    test "names a taxon by its level" do
      assert sci(name: "coccinea", level: "complex") =~
               ~s(<i class="oc-sci-g">Q.</i> <i class="oc-sci-e">coccinea</i>)

      for level <- ~w(genus subgenus section subsection) do
        html = sci(name: "Lobatae", level: level)
        refute html =~ "oc-sci-g"
        assert html =~ ~s(<span class="oc-sci-n"><i class="oc-sci-e">Lobatae</i></span>)
      end

      assert sci(name: "Quercus", level: "subgenus") =~
               ~s(<span class="oc-sci-n"><i class="oc-sci-e">Quercus</i></span>)
    end

    test "abbreviates the genus" do
      assert sci(name: "michauxii", abbreviate: true) =~ ~s(<i class="oc-sci-g">Q.</i> <i)
    end

    test "keeps the hybrid sign roman and spaced, however it is stored" do
      for {name, hybrid} <- [{"× riparia", false}, {"×riparia", false}, {"riparia", true}] do
        assert sci(name: name, hybrid: hybrid) =~
                 ~s(<i class="oc-sci-g">Quercus</i>\u00A0<span class="oc-sci-x">×</span>\u00A0<i class="oc-sci-e">riparia</i>)
      end
    end

    test "sets a formula's sign roman between its parents, never breaking the formula" do
      assert sci(name: "agrifolia × parvula") =~
               ~s(<i class="oc-sci-e">agrifolia</i>\u00A0<span class="oc-sci-x">×</span>\u00A0<i class="oc-sci-e">parvula</i>)
    end

    test "reads a stated genus and keeps rank words roman" do
      html = sci(name: "Quercus alba var. latiloba")

      assert html =~ ~s(<i class="oc-sci-g">Quercus</i> <i class="oc-sci-e">alba</i>)
      assert html =~ ~s(<span class="oc-sci-r">var.</span>\u00A0<i class="oc-sci-e">latiloba</i>)
      refute html =~ "Quercus</i> <i class=\"oc-sci-g\">"
    end

    test "sets a name above species after its rank word, with no genus" do
      html = sci(name: "Coccineae", rank: "subsect.")

      assert html =~
               ~s(<span class="oc-sci-n"><span class="oc-sci-r">subsect.</span>\u00A0<i class="oc-sci-e">Coccineae</i></span>)

      refute html =~ "oc-sci-g"
    end

    test "sets a bare name at 400 for running text" do
      html = sci(name: "Cerris", genus: nil, weight: "regular")

      assert html =~
               ~s(<span class="oc-sci oc-sci-regular"><span class="oc-sci-n"><i class="oc-sci-e">Cerris</i></span></span>)
    end

    test "sets the genus on its own as a name, and a rank's name in full" do
      assert sci(name: "Quercus") =~
               ~r{<span class="oc-sci ?"><span class="oc-sci-n"><i class="oc-sci-e">Quercus</i></span></span>}

      assert sci(name: "Quercus", rank: "subg.") =~
               ~s(<span class="oc-sci-r">subg.</span>\u00A0<i class="oc-sci-e">Quercus</i>)
    end

    test "escapes the name and author" do
      html = sci(name: "<b>alba</b>", author: "L. & <i>x</i>")

      refute html =~ "<b>"
      assert html =~ "&lt;b&gt;alba&lt;/b&gt;"
      assert html =~ "L. &amp; &lt;i&gt;x&lt;/i&gt;"
    end
  end

  describe "title_page/1" do
    test "sets the title on ink with the search across its edge and the counts below" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <DesignComponents.title_page search="/search">
          Oak <em>Compendium</em>
          <:subtitle>Oaks, their varieties and their hybrids</:subtitle>
          <:count>494 species</:count>
          <:count>238 hybrids</:count>
        </DesignComponents.title_page>
        """)

      assert html =~
               ~s(<section id="title-page" class="oc-tp" aria-labelledby="title-page-title">)

      assert html =~ ~r{<h1 id="title-page-title" class="oc-tp-title">\s*Oak <em>Compendium</em>}
      assert html =~ ~s(<p class="oc-tp-sub">Oaks, their varieties and their hybrids</p>)
      assert html =~ ~s(<form action="/search" method="get" role="search" class="oc-tp-search">)
      assert html =~ ~s(<label for="title-page-q" class="sr-only">Find an oak</label>)
      assert html =~ ~s(name="q")
      assert html =~ ~s(<button type="submit">Find</button>)
      assert html =~ ~r{<span>494 species</span>\s*<span>238 hybrids</span>}
      refute html =~ "oc-tp-edge-plain"
    end

    test "without a search the ink ends at a plain ochre edge" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <DesignComponents.title_page>Oak <em>Compendium</em></DesignComponents.title_page>
        """)

      assert html =~ "oc-tp-edge oc-tp-edge-plain"
      refute html =~ "<form"
      refute html =~ "oc-tp-counts"
    end
  end

  describe "chapter_heading/1" do
    test "is a centred h2, with the acorn on request" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <DesignComponents.chapter_heading id="c" mark>Contents</DesignComponents.chapter_heading>
        """)

      assert html =~ ~r{<h2 id="c" class="oc-chapter ?">}
      assert html =~ ~s(class="oc-chapter-cap")
      assert html =~ ~s(aria-hidden="true")

      plain =
        rendered_to_string(~H"""
        <DesignComponents.chapter_heading>An oak at random</DesignComponents.chapter_heading>
        """)

      refute plain =~ "<svg"
      assert plain =~ "An oak at random"
    end
  end

  describe "contents/1" do
    test "links each built part with its count and marks a part in preparation" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <DesignComponents.contents labelledby="contents-heading">
          <:entry title="Species" navigate="/species" count={494}>Every oak.</:entry>
          <:entry title="Taxonomy" navigate="/taxonomy" count={8} count_label="sections">
            Ranks.
          </:entry>
          <:entry title="Identify" status="In preparation">A trait filter.</:entry>
          <:entry title="About" navigate="/about">Who keeps it.</:entry>
        </DesignComponents.contents>
        """)

      assert html =~
               ~s(<nav id="contents" class="oc-contents" aria-labelledby="contents-heading">)

      assert html =~ ~s(href="/species")

      assert html =~
               ~r{<span class="oc-contents-title">Species</span>\s*<span class="oc-contents-count">\s*494}

      assert html =~ ~s(8<small>sections</small>)
      assert html =~ ~s(<div class="oc-contents-row oc-contents-off">)

      assert html =~
               ~r{<span class="oc-status border-dashed uppercase">\s*In preparation\s*</span>}

      refute html =~ ~s(href="/identify")
      assert html =~ ~s(href="/about")
    end
  end

  describe "taxonomy_band/1 inline" do
    test "is a wrapping plate with no current taxon and no pinning hook" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <DesignComponents.taxonomy_band id="b" label="Where it sits" inline>
          <:rank navigate="/taxonomy"><i>Quercus</i></:rank>
          <:rank navigate="/taxonomy/Quercus" rank="subg."><i>Quercus</i></:rank>
        </DesignComponents.taxonomy_band>
        """)

      assert html =~ ~s(class="oc-band oc-band-inline")
      assert html =~ ~s(aria-label="Where it sits")
      refute html =~ "PinCurrentTaxon"
      refute html =~ "aria-current"
    end
  end

  describe "specimen/1" do
    test "sets the taxon under its chapter heading, with each part it is given" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <DesignComponents.specimen id="s" heading="An oak at random">
          <:name>michauxii</:name>
          <:author>Nutt.</:author>
          <:about>Hybrids</:about>
          <:actions><button>Show another</button></:actions>
        </DesignComponents.specimen>
        """)

      assert html =~ ~s(<section id="s" class="oc-specimen" aria-labelledby="s-heading">)
      assert html =~ ~r{<h2 id="s-heading" class="oc-chapter ?">}
      assert html =~ ~s(<p class="oc-specimen-name">michauxii</p>)
      assert html =~ ~s(<p class="oc-specimen-author">Nutt.</p>)
      assert html =~ ~s(<p class="oc-specimen-about">Hybrids</p>)
      refute html =~ "oc-specimen-band"
    end
  end

  test "colophon/1 lists its items under a label" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <DesignComponents.colophon id="c" label="Sources">
        <:item>Oaks of the World</:item>
        <:item>Sibley</:item>
      </DesignComponents.colophon>
      """)

    assert html =~ ~s(<section id="c" class="oc-colophon" aria-labelledby="c-label">)
    assert html =~ ~s(<h2 id="c-label">Sources</h2>)
    assert html =~ ~r{<li>Oaks of the World</li>\s*<li>Sibley</li>}
  end

  test "work_title/1 sets the genus in a title as a scientific name" do
    html =
      render_component(&DesignComponents.work_title/1,
        title: "Notes on North American Trees. I. Quercus & <Quercetum>"
      )

    assert html =~
             ~r{Notes on North American Trees\. I\. <span class="oc-sci oc-sci-regular ?"><i class="oc-sci-e">Quercus</i></span>}

    assert html =~ "&amp; &lt;Quercetum&gt;"
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
