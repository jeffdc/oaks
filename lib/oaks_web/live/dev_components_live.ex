defmodule OaksWeb.DevComponentsLive do
  @moduledoc """
  A gallery of the DESIGN.md components (item 21b7), for building and
  reviewing them in the running app: every component in
  `OaksWeb.DesignComponents` and the restyled ones in
  `OaksWeb.CoreComponents`, with real content from the taxon page
  prototype (design/prototype/shumardii.html).

  Its route (`/dev/components`) exists only when
  `config :oaks, dev_routes: true` (dev and test), like the dev login, so a
  production release has none. Mount checks the setting again in case the
  module is ever routed by mistake. It renders without the app layout, so
  the components are seen on their own, not under the V1 header.
  """
  use OaksWeb, :live_view

  @traits [
    %{
      trait: "Habit",
      oak_compendium: nil,
      standing: "open",
      summary: "2 sources, not reviewed",
      others: [
        {"15-30 m tall and more; rounded open crown", "Oaks of the World"},
        {"Deciduous. Medium to large tree often 90'.", "Sibley Guide to Trees"}
      ]
    },
    %{
      trait: "Buds",
      oak_compendium:
        {"buds looks glabrous and pretty small.", "i465271504",
         "https://www.inaturalist.org/observations/190127456"},
      standing: "differs",
      summary: "Sibley differs on size",
      others: [{"large, grayish or straw-colored, and hairless", "Sibley Guide to Trees"}]
    },
    %{
      trait: "Leaves",
      oak_compendium:
        {"Glabrous angled (in cross-section) buds and lobey leaves with an overall round shape with very tight sinuses (vs the wider ones of Q coccinea).",
         "c23423264", "https://www.inaturalist.org/observations/403156034"},
      standing: "differs",
      summary: "Oaks of the World differs on lobe count",
      others: [
        {"8-18 x 6-13 cm; leathery; obovate to broad-elliptic; 3-5 pairs of lobulate, bristle-tipped, toothed lobes with deep sinuses",
         "Oaks of the World"}
      ]
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    if Application.get_env(:oaks, :dev_routes) do
      {:ok, assign(socket, page_title: "Components", traits: @traits), layout: false}
    else
      raise OaksWeb.DevComponentsLive.NotAvailable
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main id="main-content">
      <.page width="frame">
        <:bleed>
          <.taxonomy_band ranks={band_ranks(:species)} current={band_current(:species)}>
            <:siblings label="Coccineae · 7 species">
              <li :for={name <- ~w(acerifolia buckleyi coccinea ellipsoidalis rubra)}>
                <.link navigate={~p"/species/#{name}"}><.sci_name name={name} abbreviate /></.link>
              </li>
              <li><span aria-current="page"><.sci_name name="shumardii" abbreviate /></span></li>
              <li>
                <.link navigate={~p"/species/velutina"}><.sci_name name="velutina" abbreviate /></.link>
              </li>
            </:siblings>
          </.taxonomy_band>
        </:bleed>
        <:head>
          <.back navigate={~p"/"}>Back to home</.back>
          <.header>
            Components
            <:subtitle>
              The DESIGN.md system as Phoenix components, with real content from the taxon page
              prototype. Development only.
            </:subtitle>
          </.header>
        </:head>

        <div class="grid gap-s7 lg:grid-cols-2">
          <section>
            <.section_heading id="marks">
              Marks
              <:note>source, standing, status</:note>
            </.section_heading>
            <p class="max-w-[68ch] text-lg/relaxed">
              <q>buds looks glabrous and pretty small. acorn also looks like Q shumardii</q>
              <.source_mark href="https://www.inaturalist.org/observations/190127456">
                iNat i465271504 · 2024
              </.source_mark>
            </p>
            <.standing_marks class="mt-s4">
              <.standing_mark standing="agree">Oaks of the World agrees</.standing_mark>
              <.standing_mark standing="differs">Differs: Sibley gives buds as large</.standing_mark>
              <.standing_mark standing="open">2 sources, not reviewed</.standing_mark>
            </.standing_marks>
            <p class="mt-s5 flex flex-wrap items-baseline gap-s2">
              <.iucn_status code="LC" />
              <.source_mark href="#field-marks">IUCN 2024-2</.source_mark>
            </p>
            <p class="mt-s3 flex flex-wrap items-center gap-s2">
              <.iucn_status :for={code <- ~w(EX EW CR EN VU NT LC DD NE)} code={code} prefix={false} />
            </p>
          </section>

          <section>
            <.section_heading id="buttons">Buttons</.section_heading>
            <div class="flex flex-wrap items-center gap-s3">
              <.button variant="primary">Insert</.button>
              <.button>Set aside</.button>
              <.button variant="danger">Delete species</.button>
              <.button disabled>Mark written</.button>
              <.compare_button navigate={~p"/species/coccinea"} />
            </div>
            <.section_heading id="dialogs" level="h3" class="mt-s7">
              Dialogs<:note>one close control, the action last</:note>
            </.section_heading>
            <div class="flex flex-wrap items-center gap-s3">
              <.button phx-click={show_modal("gallery-modal")}>Open a confirmation</.button>
              <.button phx-click={show_modal("gallery-modal-cant")}>Open a notice</.button>
            </div>
            <.section_heading id="quiet-edit-menu" level="h3" class="mt-s7">
              Quiet edit menu<:note>editing part of a page</:note>
            </.section_heading>
            <div class="flex flex-wrap items-baseline justify-between gap-s3 border-b border-rule pb-s2 font-frame text-sm font-semibold text-ink-2">
              Data from Oaks of the World
              <.edit_menu
                id="gallery-quiet-menu"
                quiet
                aria_label="Edit the data from Oaks of the World"
              >
                <:item click="noop">Edit source data</:item>
                <:item click="noop">Delete source data</:item>
              </.edit_menu>
            </div>
            <.section_heading id="list" level="h3" class="mt-s7">List</.section_heading>
            <.list>
              <:item title="Authority">Buckley</:item>
              <:item title="Common name">Shumard oak</:item>
              <:item title="Lobes per side">
                <span class="lining-nums tabular-nums">3–4</span>, rarely 2
              </:item>
            </.list>
          </section>
        </div>

        <section class="mt-s8">
          <.section_heading id="field-marks">
            Field marks
            <:note>Oak Compendium first, other sources behind</:note>
          </.section_heading>
          <.table id="field-marks-table" rows={@traits} row_id={&"trait-#{&1.trait}"} stack>
            <:col :let={t} label="Trait" row_header>{t.trait}</:col>
            <:col :let={t} label="Oak Compendium" voice>
              <%= if t.oak_compendium do %>
                <% {quote, mark, href} = t.oak_compendium %>
                <q>{quote}</q>
                <.source_mark href={href}>{mark}</.source_mark>
              <% else %>
                <.no_statement />
              <% end %>
            </:col>
            <:col :let={t} label="Other sources">
              <.other_sources standing={t.standing} summary={t.summary}>
                <:source :for={{text, by} <- t.others} by={by}>{text}</:source>
              </.other_sources>
            </:col>
          </.table>
        </section>

        <div class="mt-s8 grid gap-s7 lg:grid-cols-2">
          <section>
            <.section_heading id="fields">Form fields</.section_heading>
            <form id="gallery-form" phx-submit="noop" phx-change="noop">
              <.input name="name" label="Name" value="Quercus shumardii" />
              <.input
                name="authority"
                label="Authority"
                value=""
                placeholder="e.g. Buckley"
                errors={["can't be blank"]}
              />
              <.input
                name="rank"
                type="select"
                label="Rank"
                options={["Species", "Variety", "Hybrid"]}
                value="Species"
              />
              <.input
                name="notes"
                type="textarea"
                label="Notes"
                value="Fall color is usually yellowish."
              />
              <.input name="published" type="checkbox" label="Published" value="true" />
              <.button type="submit" variant="primary">Save</.button>
            </form>
          </section>

          <section>
            <.section_heading id="notices">Notices</.section_heading>
            <div class="grid gap-s3 [&_.oc-flash]:static [&_.oc-flash]:w-full">
              <.flash id="gallery-flash-info" kind={:info}>Source saved.</.flash>
              <.flash id="gallery-flash-error" kind={:error} title="Something went wrong!">
                Attempting to reconnect
              </.flash>
            </div>
          </section>
        </div>

        <section class="mt-s8">
          <.section_heading id="photo-editing">
            Photo editing
            <:note>the species page's Add photos and Manage photos dialogs</:note>
          </.section_heading>
          <div class="grid gap-s7 lg:grid-cols-2">
            <form id="gallery-photo-pick" phx-change="noop" phx-submit="noop" class="max-w-[34rem]">
              <.input
                id="gallery-observation"
                name="observation"
                label="iNaturalist observation"
                value="inaturalist.org/observations/190127456"
                placeholder="Observation URL or number"
              >
                <:action><.button type="submit">Load</.button></:action>
              </.input>
              <.photo_picker id="gallery-photo-picker">
                <.photo_tile label="Photo 1, CC-BY-NC" name="photo_ids[]" value="1" checked>
                  CC-BY-NC
                </.photo_tile>
                <.photo_tile label="Photo 2, CC-BY" name="photo_ids[]" value="2">CC-BY</.photo_tile>
                <.photo_tile label="Photo 3, All rights reserved" name="photo_ids[]" value="3" checked>
                  <.status_tag>All rights reserved</.status_tag>
                </.photo_tile>
                <.photo_tile label="Photo 4, No license given" name="photo_ids[]" value="4">
                  <.status_tag>No license given</.status_tag>
                </.photo_tile>
                <.photo_tile label="Photo 5" off><.photo_status status="exists" /></.photo_tile>
                <.photo_tile label="Photo 6"><.photo_status status="added" /></.photo_tile>
                <.photo_tile label="Photo 7"><.photo_status status="adding" /></.photo_tile>
                <.photo_tile label="Photo 8">
                  <.photo_status status="failed" error="iNaturalist no longer has this photo.">
                    <:action><.button type="button" size="compact">Retry</.button></:action>
                  </.photo_status>
                </.photo_tile>
              </.photo_picker>
              <.ruled_notice id="gallery-permission" class="mt-s4">
                <p>
                  <strong>Photo 3 is All rights reserved.</strong>
                  Its creator keeps every right to it. Add it only if the creator has given the
                  Oak Compendium permission. The page will say it is used with the creator's
                  permission.
                </p>
                <:confirm>
                  <.input
                    type="checkbox"
                    name="permission"
                    label="The creator has given permission to use this photo."
                  />
                </:confirm>
              </.ruled_notice>
            </form>

            <div class="max-w-[34rem]">
              <.photo_list id="gallery-photo-list" on_reorder="noop">
                <.photo_row
                  :for={
                    {id, caption, state} <- [
                      {1, "Terminal buds in winter", :ready},
                      {2, "", :reserved},
                      {3, "", :adding},
                      {4, "", :failed}
                    ]
                  }
                  id={"gallery-photo-#{id}"}
                  photo_id={id}
                  label={"Photo #{id}"}
                  muted={state in [:adding, :failed]}
                  on_delete={JS.push("noop")}
                >
                  <.input
                    id={"gallery-caption-#{id}"}
                    name="caption"
                    value={caption}
                    placeholder="Caption"
                    aria-label="Caption"
                    disabled={state in [:adding, :failed]}
                  />
                  <:meta>
                    <.photo_credit :if={state == :ready} creator="janedoe" license="CC-BY-NC" />
                    <.photo_credit
                      :if={state == :reserved}
                      creator="janedoe"
                      license="All rights reserved, used with the creator's permission"
                      reserved
                    />
                    <.photo_status :if={state == :adding} status="adding" />
                    <.photo_status
                      :if={state == :failed}
                      status="failed"
                      error="The photo couldn't be read as an image."
                    >
                      <:action><.button type="button" size="compact">Retry</.button></:action>
                    </.photo_status>
                  </:meta>
                </.photo_row>
              </.photo_list>
            </div>
          </div>
        </section>

        <section class="mt-s8">
          <.section_heading id="names">
            Scientific names<:note>sci_name</:note>
          </.section_heading>
          <.list>
            <:item title="Species, author">
              <.sci_name name="shumardii" author="Buckley" />
            </:item>
            <:item title="Abbreviated">
              <.sci_name name="shumardii" abbreviate />
            </:item>
            <:item title="Named hybrid">
              <.sci_name name="× riparia" author="Laughlin" />
            </:item>
            <:item title="Hybrid flag, no sign stored">
              <.sci_name name="riparia" hybrid abbreviate />
            </:item>
            <:item title="Formula">
              <.sci_name name="agrifolia × parvula" />
            </:item>
            <:item title="Infraspecific">
              <.sci_name name="agrifolia oxyadenia" abbreviate />
            </:item>
            <:item title="Rank word">
              <.sci_name name="Quercus alba var. latiloba" />
            </:item>
            <:item title="Above species">
              <.sci_name name="Coccineae" rank="subsect." />
            </:item>
            <:item title="A taxon by its level">
              <.sci_name name="Lobatae" level="section" />,
              <.sci_name name="coccinea" level="complex" />
            </:item>
            <:item title="Authority stored in the name">
              <.sci_name name="shumardii var. acerifolia E.J.Palmer 1927" genus={nil} />
            </:item>
            <:item title="Synonyms, under a species">
              <.sci_name name="candida Steud." abbreviate />,
              <.sci_name name="texana Auctores" abbreviate />,
              <.sci_name name="repanda hort." abbreviate />,
              <.sci_name name="Cyclobalanopsis glauca (Thunb.) Oerst." abbreviate />
            </:item>
            <:item title="In running text">
              Two subgenera, <.sci_name name="Quercus" genus={nil} weight="regular" /> and
              <.sci_name name="Cerris" genus={nil} weight="regular" />.
            </:item>
          </.list>
          <p class="mt-s6 max-w-[68ch]">
            Size follows the name's role, never the page: <code>size="display"</code>
            in a title row, <code>"headline"</code>
            heading a comparison column, <code>"title"</code>
            for a name that is a list entry, <code>"meta"</code>
            in a metadata line beside one, and no size elsewhere (running text, dialogs, table
            cells), where it takes the text around it. The genus is in full in titles, at
            a first mention and in lists whose entries stand alone; Q. after that, in lists under a
            named taxon or record (a species' synonyms too), and in column heads; none above species
            and after "with". Only Quercus is abbreviated: a synonym in another genus keeps it
            in full.
          </p>
          <.list>
            <:item title="display">
              <.sci_name name="shumardii" author="Buckley" size="display" />
            </:item>
            <:item title="headline">
              <.sci_name name="coccinea" abbreviate size="headline" />
            </:item>
            <:item title="title">
              <.sci_name name="× riparia" author="Laughlin" size="title" />
            </:item>
            <:item title="title, abbreviated">
              <.link navigate={~p"/species/× riparia"}>
                <.sci_name name="× riparia" abbreviate size="title" />
              </.link>
              <span class="text-ink-2">
                with <.sci_name name="rubra" genus={nil} weight="regular" />
              </span>
            </:item>
            <:item title="meta">
              <span class="text-ink-3">
                <.sci_name name="Quercus" rank="subg." size="meta" />
                <.sci_name name="Lobatae" rank="sect." size="meta" />
              </span>
            </:item>
          </.list>
        </section>

        <section class="mt-s8">
          <.section_heading id="title-pages">
            Title page and contents<:note>
              title_page, chapter_heading, contents, specimen, colophon
            </:note>
          </.section_heading>
          <p class="max-w-[68ch]">
            The home page's pieces. On a page the title page runs in the bleed, so its ink spans
            the window; here it sits in the frame. Its search submits to the search page.
          </p>
          <div class="mt-s5">
            <.title_page id="gallery-title-page" search={~p"/search"}>
              Oak <em>Compendium</em>
              <:subtitle>
                Oaks, their varieties and their hybrids, and how to tell them apart
              </:subtitle>
              <:count>494 species</:count>
              <:count>238 hybrids</:count>
              <:count>8 sections</:count>
              <:count>4 sources</:count>
            </.title_page>
          </div>
          <.chapter_heading id="gallery-contents-heading" mark class="mt-s8">
            Contents
          </.chapter_heading>
          <.contents id="gallery-contents" labelledby="gallery-contents-heading">
            <:entry title="Species" navigate={~p"/species"} count={494}>
              Every oak, A to Z, each on its own page.
            </:entry>
            <:entry title="Taxonomy" navigate={~p"/taxonomy"} count={8} count_label="sections">
              Two subgenera, <.sci_name name="Quercus" genus={nil} weight="regular" /> and
              <.sci_name name="Cerris" genus={nil} weight="regular" />, their sections and
              subsections, every rank linked.
            </:entry>
            <:entry title="Identify" status="In preparation">
              A trait filter that narrows the oaks by what you can see, and a helper for hybrids.
            </:entry>
            <:entry title="About" navigate={~p"/about"}>
              What the Compendium is and who keeps it.
            </:entry>
          </.contents>
          <.specimen id="gallery-specimen" heading="An oak at random">
            <:name><.sci_name name="shumardii" /></:name>
            <:author>Buckley</:author>
            <:band>
              <.taxonomy_band
                id="gallery-band-inline"
                label="Where it sits"
                ranks={band_ranks(:species)}
                inline
              />
            </:band>
            <:about>
              Hybrids
              <.link navigate={~p"/species/× riparia"}>
                <.sci_name name="× riparia" abbreviate />
              </.link>
              with <.sci_name name="rubra" genus={nil} weight="regular" />
            </:about>
            <:actions>
              <.button variant="primary" navigate={~p"/species/shumardii"}>Open the page</.button>
              <.button>Show another</.button>
            </:actions>
          </.specimen>
          <.colophon id="gallery-colophon" label="Sources">
            <:item>
              <.link navigate={~p"/sources/3"}>Oak Compendium</.link><.status_tag>
                Primary
              </.status_tag>
            </:item>
            <:item><.link navigate={~p"/sources/2"}>Oaks of the World</.link></:item>
            <:item>
              <.link navigate={~p"/sources/5"}>
                <.work_title title="Notes on North American Trees. I. Quercus" />
              </.link>
            </:item>
          </.colophon>
        </section>

        <section class="mt-s8">
          <.section_heading id="title-row">
            Title row<:note>title and meta on one line, the edit menu at the right</:note>
          </.section_heading>
          <p class="max-w-[68ch]">
            Every page's title is one <code>header</code>. The meta (a kind word, counts, a byline,
            stamps) follows the title on its line and wraps under it only when the line has no
            room; a subtitle goes under the line. An editor's actions are one small
            <code>edit_menu</code>
            at the right on the title's first baseline, which never wraps; logged out there is none
            and the title takes the whole row. The first row is an editor's, the second a visitor's;
            the last two are the same rows at a phone's width.
          </p>
          <div class="mt-s5 grid gap-s7">
            <.header id="gallery-title-record">
              <.sci_name name="Quercus shumardii" author="Buckley" size="display" />
              <:meta>Species</:meta>
              <:meta><.iucn_status code="LC" /></:meta>
              <:actions>
                <.edit_menu id="gallery-edit-menu">
                  <:item click="noop">Edit species</:item>
                  <:item click="noop">Make synonym of…</:item>
                  <:item click="noop">Delete species</:item>
                </.edit_menu>
              </:actions>
            </.header>
            <.header id="gallery-title-visitor">
              <.sci_name name="Quercus shumardii" author="Buckley" size="display" />
              <:meta>Species</:meta>
              <:meta><.iucn_status code="LC" /></:meta>
            </.header>
            <.header id="gallery-title-list">
              Species list
              <:meta>640 species</:meta>
              <:meta>94 hybrids</:meta>
              <:meta><strong>734 total</strong></:meta>
              <:actions>
                <.edit_menu id="gallery-edit-menu-list">
                  <:item click="noop">New species</:item>
                </.edit_menu>
              </:actions>
            </.header>
            <.header id="gallery-title-work">
              <.work_title title="Notes on North American Trees. I. Quercus" />
              <:meta>
                <.status_tag>Article</.status_tag>
              </:meta>
              <:subtitle>
                The Oak Compendium draws from multiple sources to provide comprehensive
                information about oak species.
              </:subtitle>
            </.header>
            <div class="grid gap-s7 sm:grid-cols-2">
              <div class="max-w-[390px] border border-dashed border-rule p-s4">
                <.header id="gallery-title-narrow">
                  <.sci_name name="Quercus shumardii" author="Buckley" size="display" />
                  <:meta>Species</:meta>
                  <:meta><.iucn_status code="LC" /></:meta>
                  <:actions>
                    <.edit_menu id="gallery-edit-menu-narrow">
                      <:item click="noop">Edit species</:item>
                      <:item click="noop">Make synonym of…</:item>
                      <:item click="noop">Delete species</:item>
                    </.edit_menu>
                  </:actions>
                </.header>
              </div>
              <div class="max-w-[390px] border border-dashed border-rule p-s4">
                <.header id="gallery-title-narrow-visitor">
                  <.sci_name name="Quercus shumardii" author="Buckley" size="display" />
                  <:meta>Species</:meta>
                  <:meta><.iucn_status code="LC" /></:meta>
                </.header>
              </div>
            </div>
          </div>
        </section>

        <section class="mt-s8">
          <.section_heading id="band">
            Taxonomy band<:note>one line, one height, on every taxon page</:note>
          </.section_heading>
          <p class="max-w-[68ch]">
            Every taxon page puts the band in its page's bleed, straight under the masthead: taxonomy
            pages, species, hybrids, varieties and the source comparison. The band sets each step
            itself from data, so the crumbs read the same everywhere. A hybrid with no ranks of its
            own sits where both its parents do, down to the last rank they share; a variety sits
            under its species. On phones the line scrolls, pinned to the current taxon.
          </p>
          <.list>
            <:item
              :for={
                {kind, label} <- [
                  taxon: "a section",
                  species: "a species",
                  named_hybrid: "a named hybrid",
                  formula_hybrid: "a formula hybrid",
                  genus_hybrid: "parents in two subgenera",
                  variety: "a variety"
                ]
              }
              title={label}
            >
              <.taxonomy_band
                id={"gallery-band-#{kind}"}
                ranks={band_ranks(kind)}
                current={band_current(kind)}
              />
            </:item>
          </.list>
        </section>

        <section class="mt-s8">
          <.section_heading id="page">
            Page<:note>column, read, form and frame widths; the head; the bleed</:note>
          </.section_heading>
          <p class="max-w-[68ch]">
            This gallery is a <code>page</code> at the frame: the band above runs in its bleed, the
            window's full width, and everything else sits in the 1400px frame, which only pages that
            set columns side by side take (the source comparison, a merge). Every single-column page
            sits in one centred 960px column: lists, taxon pages and records take column. Prose takes
            read (720px) and forms and account pages take form (760px), narrower centred columns
            whose head and content share the measure. The head spans the page's width.
          </p>
          <div :for={width <- ~w(column read form)} class="mt-s5 border border-dashed border-rule">
            <.page id={"gallery-page-#{width}"} width={width}>
              <:head>
                <.header>width="{width}"</.header>
              </:head>
              <p>
                The page answers "is it this, or that?" before anything else. Where the taxon sits
                is shown in the same ochre band on every taxon page; the traits that set it apart
                come first; look-alikes and hybrids sit one step away; a side-by-side comparison
                aligns two taxa trait by trait.
              </p>
            </.page>
          </div>
        </section>

        <section class="mt-s8">
          <.section_heading id="not-found">
            Not found and errors<:note>the 404, 403 and 500 pages, at the reading measure</:note>
          </.section_heading>
          <p class="max-w-[68ch]">
            Shown only with a real error status, in the site's masthead and footer. A LiveView that
            finds nothing at its address raises <code>OaksWeb.NotFoundError</code>
            with a kind (page, species, taxon, source or article), which picks the title, the line
            and the index offered; an address with no route is a page. Below: a species asked for
            under a mistyped name, with a page to go back to. The 403 and 500 are the same notice
            with their own words.
          </p>
          <div class="mt-s5 border border-dashed border-rule">
            <.page id="gallery-page-not-found" width="read">
              <.not_found
                id="gallery-not-found"
                kind={:species}
                path="/species/shumardi-typo"
                query="shumardi-typo"
                back={~p"/dev/components"}
              />
            </.page>
          </div>
          <div class="mt-s5 border border-dashed border-rule">
            <.page id="gallery-page-error" width="read">
              <.error_notice id="gallery-error-notice" status="500" title="Something went wrong">
                The Compendium hit an error and couldn’t show this page. It wasn’t anything you did.
                Try again in a moment, or start again from the home page.
                <:actions>
                  <.button href={~p"/"} variant="primary">Home</.button>
                </:actions>
              </.error_notice>
            </.page>
          </div>
        </section>
      </.page>
    </main>

    <.modal id="gallery-modal">
      <:title>Delete species</:title>
      <p>
        Delete <.sci_name name="Quercus shumardii" weight="regular" /> from the Compendium?
      </p>
      <:note>Its data from 2 sources goes with it.</:note>
      <:note><strong>This can't be undone.</strong></:note>
      <:actions>
        <.button variant="danger" phx-click={JS.exec("data-cancel", to: "#gallery-modal")}>
          Delete species
        </.button>
      </:actions>
    </.modal>

    <.modal id="gallery-modal-cant" cancel="Close">
      <:title>Can't delete source</:title>
      <p>3 species have data from <strong>The Sibley Guide to Trees</strong>.</p>
      <:note>Delete that data on each species' page first.</:note>
    </.modal>
    """
  end

  @impl true
  def handle_event("noop", _params, socket), do: {:noreply, socket}

  # The band's examples: where each kind of taxon page's band starts from
  # (as Oaks.Species.placement/1 gives it) and its current step.
  @band_examples %{
    species:
      {~w(subgenus:Quercus section:Lobatae subsection:Coccineae complex:shumardii),
       {"species", "shumardii", false}},
    taxon: {~w(subgenus:Quercus), {"section", "Lobatae", false}},
    named_hybrid: {~w(subgenus:Quercus section:Quercus), {"species", "× bebbiana", true}},
    formula_hybrid:
      {~w(subgenus:Quercus section:Lobatae subsection:Agrifoliae),
       {"species", "agrifolia × parvula", true}},
    genus_hybrid: {[], {"species", "× albescens", true}},
    variety:
      {~w(subgenus:Cerris section:Cerris subsection:Campylolepides species:acutissima),
       {"species", "acutissima kingii", false}}
  }

  defp band_ranks(kind) do
    {placement, _current} = @band_examples[kind]

    placement
    |> Enum.map(fn step ->
      [level, name] = String.split(step, ":")
      %{level: level, name: name, hybrid: false}
    end)
    |> OaksWeb.TaxonPath.ranks()
  end

  defp band_current(kind) do
    {_placement, {level, name, hybrid}} = @band_examples[kind]
    %{level: level, name: name, hybrid: hybrid}
  end

  defmodule NotAvailable do
    @moduledoc false
    defexception message: "the component gallery is a dev route", plug_status: 404
  end
end
