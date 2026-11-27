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

  import Ecto.Query, only: [from: 2]
  import Heartwood.UI.PhotoViewer, only: [photo_viewer: 1]

  # The gallery's own path, as a plain string: ~p can't verify it in a prod
  # compile, where the /dev routes don't exist, so it would warn there.
  @gallery_path "/dev/components"

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

  # Q. shumardii's text by source, from the database (as in
  # design/prototype/species-today.html), in the species page's order, and
  # Q. × riparia's empty Oak Compendium row.
  @source_texts [
    %{
      id: 3,
      name: "Oak Compendium",
      about: "/sources/3",
      fields: [
        {"Leaves", "Lobes per side: usually 3–4, rarely as few as 2."},
        {"Fruits",
         "The cap is saucer shaped like Q. rubra rather than turbinate. Acorns can get pretty big and look a lot like the classic \"fat man in a beret\" acorns of Q. rubra, so you have to be careful with acorns."},
        {"Twigs",
         "My rough conclusion, from one area and some iNat data, is that new stems are always green, vs sometimes red with Q. palustris."}
      ]
    },
    %{
      id: 2,
      name: "Oaks of the World",
      original: "https://oaksoftheworld.fr/quercus_shumardii.htm",
      fields: [
        {"Common names", "Shumard's oak"},
        {"Geographic range",
         "South Ontario; Eastern and Central USA; introduced in Europe in 1908;"},
        {"Growth habit", "15-30 m tall and more; rounded open crown;"},
        {"Leaves",
         "8-18 x 6-13 cm; leathery; obovate to broad-elliptic; 3-5 pairs of lobulate, bristle-tipped, toothed lobes with deep sinuses; apex acute; base obtuse to acute; lustrous dark green, hairless above; paler, glabrous beneath except large axillary tufts of rusty hairs; red at fall; petiole hairless 3-6 cm long;"},
        {"Flowers", "spring"},
        {"Hardiness and habitat",
         "hardy; all types of soils, but prefers moist and rich ones; rather fast-growing;"}
      ]
    },
    %{
      id: 4,
      name: "The Sibley Guide to Trees",
      about: "/sources/4",
      fields: [
        {"Common names", "Shumard Oak, Leopard Oak, Spotted Oak"},
        {"Growth habit", "Deciduous. Medium to large tree often 90'."},
        {"Leaves",
         "- 6 1/2\"\n- squarish lobes end in multiple bristles\n- shiny green above and below\n- usually orange, felty hairs in vein junctures of underleaf"},
        {"Buds", "large, grayish or straw-colored, and hairless"}
      ]
    },
    %{id: 5, name: "Notes on North American Trees. I. Quercus", about: "/sources/5", fields: []}
  ]

  @gallery_hybrids [
    %{name: "× discreta", other: "velutina"},
    %{name: "× egglestonii", other: "imbricaria"},
    %{name: "× hastingsii", other: "marilandica"},
    %{name: "× joorii", other: "falcata"},
    %{name: "× moultonensis", other: "phellos"},
    %{name: "× mutabilis", other: "palustris"},
    %{name: "× neopalmeri", other: "nigra"},
    %{name: "× riparia", other: "rubra"},
    %{name: "× sternbergii", other: nil}
  ]

  @impl true
  def mount(_params, _session, socket) do
    if Application.get_env(:oaks, :dev_routes) do
      {:ok,
       assign(socket,
         page_title: "Components",
         gallery_path: @gallery_path,
         traits: @traits,
         sample_photos: sample_photos(),
         db_photos: db_photos(),
         source_texts: @source_texts,
         gallery_hybrids: @gallery_hybrids,
         gallery_tab: 3
       ), layout: false}
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
                <:meta>
                  janedoe · Blue Ridge, VA · 2026-05-04 ·
                  <.sci_name name="Quercus shumardii" genus={nil} weight="regular" />
                </:meta>
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
          <.section_heading id="photos">
            Photos
            <:note>
              heartwood_ui's photo_viewer, themed by .oc-photos as species_photos shows it: many, one and none
            </:note>
          </.section_heading>
          <div class="grid gap-s7 md:grid-cols-[300px_240px_300px]">
            <.photo_viewer
              id="gallery-photos-many"
              label="Quercus shumardii"
              photos={@sample_photos}
              class="oc-photos"
            />
            <.photo_viewer
              id="gallery-photos-one"
              label="Quercus shumardii"
              photos={Enum.take(@sample_photos, 1)}
              class="oc-photos"
            />
            <.photo_viewer
              id="gallery-photos-none"
              label="Quercus shumardii"
              photos={[]}
              class="oc-photos"
            />
          </div>
          <div :if={@db_photos} class="mt-s7 grid gap-s7 md:grid-cols-[300px_minmax(0,1fr)]">
            <.species_photos
              id="gallery-species-photos"
              images={@db_photos.images}
              name={@db_photos.name}
            />
            <p class="text-ink-3">
              <.sci_name name={@db_photos.name} />: this database's photos, through species_photos.
            </p>
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
          <.specimen
            :if={@db_photos}
            id="gallery-specimen-photo"
            heading="An oak at random, with a photo"
            photo={List.first(@db_photos.images)}
            photo_label={@db_photos.name}
            photo_navigate={~p"/species/#{@db_photos.name}"}
          >
            <:name><.sci_name name={@db_photos.name} /></:name>
            <:actions>
              <.button variant="primary" navigate={~p"/species/#{@db_photos.name}"}>
                Open the page
              </.button>
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
          <.section_heading id="species-page">
            Species page<:note>
              photo_columns, source_tabs, ruled_rows, hybrid_rows, comma_list, not_covered_notice,
              cite_line
            </:note>
          </.section_heading>
          <p class="max-w-[68ch]">
            The parts of the species page for today's data (design/prototype/species-today.html).
            The title row names the common name the source order picks, with its source's mark,
            which opens that source's tab; a hybrid's parents are its subtitle. The not-covered
            notice goes under it when the Oak Compendium has no text for the taxon. Then the photos
            beside the source tabs: one tab per source, the open one with its one icon link (the
            original page, else the source's page here), the editor's quiet Edit menu and Compare at
            the right. Below: the sections, each a section heading over its rows, and the cite line.
          </p>
          <div class="mt-s6 grid gap-s7">
            <.header id="gallery-species-title">
              <.sci_name name="Quercus shumardii" author="Buckley" size="display" />
              <:common_name>
                Shumard's oak<.source_mark patch={@gallery_path}>
                  Oaks of the World
                </.source_mark>
              </:common_name>
              <:meta>Species</:meta>
              <:meta><.iucn_status code="LC" /></:meta>
              <:actions>
                <.edit_menu id="gallery-species-menu">
                  <:item click="noop">Edit species</:item>
                  <:item click="noop">Add source data</:item>
                  <:item click="noop">Add photos from iNaturalist…</:item>
                  <:item click="noop" note="1 failed">Manage photos…</:item>
                  <:item click="noop">Make synonym of…</:item>
                  <:item click="noop">Delete species</:item>
                </.edit_menu>
              </:actions>
            </.header>
            <div>
              <.header id="gallery-hybrid-title">
                <.sci_name name="Quercus × riparia" author="Laughlin" size="display" />
                <:meta>Hybrid</:meta>
                <:subtitle>
                  Hybrid of
                  <.link navigate={~p"/species/rubra"}>
                    <.sci_name name="rubra" abbreviate weight="regular" />
                  </.link>
                  and
                  <.link navigate={~p"/species/shumardii"}>
                    <.sci_name name="shumardii" abbreviate weight="regular" />
                  </.link>
                </:subtitle>
              </.header>
              <.not_covered_notice id="gallery-not-covered">
                Everything on this page comes from the sources listed, shown as they wrote it.
              </.not_covered_notice>
            </div>

            <.photo_columns id="gallery-photo-columns">
              <:photos>
                <.photo_viewer
                  id="gallery-columns-photos"
                  label="Quercus shumardii"
                  photos={@sample_photos}
                  class="oc-photos"
                />
              </:photos>
              <.source_tabs
                id="gallery-source-tabs"
                selected={@gallery_tab}
                on_select="gallery_select_tab"
              >
                <:tab
                  :for={source <- @source_texts}
                  id={source.id}
                  name={source.name}
                  original={source[:original]}
                  about={source[:about]}
                />
                <:action>
                  <.edit_menu
                    id="gallery-source-menu"
                    quiet
                    aria_label={"Edit the data from #{gallery_source(@gallery_tab).name}"}
                  >
                    <:item click="noop">Edit {gallery_source(@gallery_tab).name} data</:item>
                    <:item click="noop">Delete {gallery_source(@gallery_tab).name} data</:item>
                  </.edit_menu>
                </:action>
                <:action>
                  <.compare_button navigate={~p"/species/shumardii/compare"}>
                    Compare sources
                  </.compare_button>
                </:action>
                <:field :for={{label, text} <- gallery_source(@gallery_tab).fields} label={label}>
                  <div class="oc-prose">{raw(Oaks.Markdown.render_html(text))}</div>
                </:field>
              </.source_tabs>
            </.photo_columns>

            <section>
              <.section_heading>
                Synonyms<:note>2 names</:note>
              </.section_heading>
              <.comma_list id="gallery-synonyms">
                <:item><.sci_name name="schneckii" abbreviate /></:item>
                <:item><.sci_name name="texana Auctores" abbreviate /></:item>
              </.comma_list>
            </section>
            <section>
              <.section_heading>Subspecies and varieties</.section_heading>
              <.ruled_rows id="gallery-varieties">
                <:row :for={name <- ["shumardii acerifolia", "shumardii schneckii"]}>
                  <.sci_name name={name} abbreviate size="title" />
                </:row>
              </.ruled_rows>
            </section>
            <section>
              <.section_heading>
                Hybrids<:note>9 known</:note>
              </.section_heading>
              <.hybrid_rows id="gallery-hybrids" hybrids={@gallery_hybrids} />
            </section>
            <section>
              <.section_heading>External links</.section_heading>
              <.ruled_rows id="gallery-links">
                <:row
                  :for={
                    {name, url} <- [
                      {"Fire Effects Information System",
                       "https://www.fs.usda.gov/database/feis/plants/tree/queshu/all.html"},
                      {"Flora of North America", "https://floranorthamerica.org/Quercus_shumardii"},
                      {"iNaturalist", "https://www.inaturalist.org/search?q=Quercus%20shumardii"},
                      {"USDA Plants Database", "https://plants.usda.gov/plant-profile/QUSH"},
                      {"Wikipedia", "https://en.wikipedia.org/wiki/Quercus_shumardii"}
                    ]
                  }
                  href={url}
                  note={URI.parse(url).host |> String.replace_prefix("www.", "")}
                >
                  {name}
                </:row>
              </.ruled_rows>
            </section>
            <section>
              <.section_heading>Sources</.section_heading>
              <.ruled_rows id="gallery-sources" columns={1}>
                <:row :for={source <- @source_texts}>
                  <.link navigate={source[:about] || ~p"/sources/2"}>
                    <.work_title title={source.name} />
                  </.link>
                  <.source_mark :if={source[:original]} href={source[:original]}>
                    original page
                  </.source_mark>
                </:row>
              </.ruled_rows>
            </section>
            <.cite_line id="gallery-cite">
              Oak Compendium. <.sci_name name="Quercus shumardii" author="Buckley" />.
              https://oakcompendium.org/species/shumardii (accessed 2026-11-25).
            </.cite_line>
          </div>
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
                  <:item click="noop" note="1 failed">Manage photos…</:item>
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
                back={@gallery_path}
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

  def handle_event("gallery_select_tab", %{"id" => id}, socket) do
    id = OaksWeb.Params.int(id)

    if Enum.any?(@source_texts, &(&1.id == id)),
      do: {:noreply, assign(socket, gallery_tab: id)},
      else: {:noreply, socket}
  end

  defp gallery_source(id), do: Enum.find(@source_texts, &(&1.id == id))

  @sample_captions [
    "Terminal buds in winter",
    nil,
    "Leaf underside, axillary tufts",
    nil,
    "Acorn and cap",
    "Bark of a mature tree"
  ]
  @sample_licenses ["CC-BY-NC", "CC-BY", "Public Domain / CC0", :reserved, "CC-BY-SA"]

  # Fourteen placeholder photos for the viewer, as species_photos passes
  # them: drawn tiles, landscape and portrait, with captions, credits and
  # licenses (one All Rights Reserved).
  defp sample_photos do
    for n <- 1..14 do
      license = Enum.at(@sample_licenses, rem(n - 1, length(@sample_licenses)))
      src = sample_image(n)

      %{
        src: src,
        thumb: src,
        full: src,
        caption: Enum.at(@sample_captions, rem(n - 1, length(@sample_captions))),
        creator: "janedoe - Jane Doe",
        license:
          if(license == :reserved,
            do: "All rights reserved, used with the creator's permission",
            else: license
          ),
        licenselink: license != :reserved && "https://creativecommons.org/licenses/",
        reserved: license == :reserved,
        sourcelink: "https://www.inaturalist.org/observations/190127456",
        source_label: "iNaturalist observation"
      }
    end
  end

  # The ready photos of the first species in this database that has any,
  # to show species_photos with real images (nil when there are none).
  defp db_photos do
    species_id =
      Oaks.Repo.one(
        from(i in Oaks.Images.Image,
          where: i.status == "ready",
          select: i.species_id,
          order_by: i.species_id,
          limit: 1
        )
      )

    if species_id do
      species = Oaks.Repo.get!(Oaks.Species.Species, species_id)
      %{name: species.scientific_name, images: Oaks.Images.list_for_species(species_id)}
    end
  end

  defp sample_image(n) do
    {w, h} = if rem(n, 3) == 0, do: {600, 800}, else: {800, 600}
    hue = rem(n * 47, 360)

    svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="#{w}" height="#{h}" viewBox="0 0 #{w} #{h}">\
    <rect width="100%" height="100%" fill="hsl(#{hue} 28% 52%)"/>\
    <rect x="24" y="24" width="#{w - 48}" height="#{h - 48}" fill="none" stroke="#fbfbf7" stroke-width="4"/>\
    <text x="50%" y="50%" fill="#fbfbf7" font-family="sans-serif" font-size="120" font-weight="700" \
    text-anchor="middle" dominant-baseline="central">#{n}</text></svg>
    """

    "data:image/svg+xml;base64," <> Base.encode64(svg)
  end

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
