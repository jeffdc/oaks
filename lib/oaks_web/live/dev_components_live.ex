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
      jeff: nil,
      standing: "open",
      summary: "2 sources, not reviewed",
      others: [
        {"15-30 m tall and more; rounded open crown", "Oaks of the World"},
        {"Deciduous. Medium to large tree often 90'.", "Sibley Guide to Trees"}
      ]
    },
    %{
      trait: "Buds",
      jeff:
        {"buds looks glabrous and pretty small.", "i465271504",
         "https://www.inaturalist.org/observations/190127456"},
      standing: "differs",
      summary: "Sibley differs on size",
      others: [{"large, grayish or straw-colored, and hairless", "Sibley Guide to Trees"}]
    },
    %{
      trait: "Leaves",
      jeff:
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
          <.taxonomy_band>
            <:rank navigate={~p"/taxonomy"}><i>Quercus</i></:rank>
            <:rank navigate={~p"/taxonomy/Quercus"} rank="subg."><i>Quercus</i></:rank>
            <:rank navigate={~p"/taxonomy/Quercus/Lobatae"} rank="sect."><i>Lobatae</i></:rank>
            <:rank navigate={~p"/taxonomy/Quercus/Lobatae/Coccineae"} rank="subsect.">
              <i>Coccineae</i>
            </:rank>
            <:rank navigate={~p"/species/shumardii"} rank="complex" rank_after>
              <i>shumardii</i>
            </:rank>
            <:current><i>Q. shumardii</i></:current>
            <:siblings label="Coccineae · 7 species">
              <li><.link navigate={~p"/species/acerifolia"}>Q. acerifolia</.link></li>
              <li><.link navigate={~p"/species/buckleyi"}>Q. buckleyi</.link></li>
              <li><.link navigate={~p"/species/coccinea"}>Q. coccinea</.link></li>
              <li><.link navigate={~p"/species/ellipsoidalis"}>Q. ellipsoidalis</.link></li>
              <li><.link navigate={~p"/species/rubra"}>Q. rubra</.link></li>
              <li><span aria-current="page">Q. shumardii</span></li>
              <li><.link navigate={~p"/species/velutina"}>Q. velutina</.link></li>
            </:siblings>
          </.taxonomy_band>
        </:bleed>
        <.back navigate={~p"/"}>Oak Compendium home</.back>

        <.header class="mt-s4">
          Components
          <:subtitle>
            The DESIGN.md system as Phoenix components, with real content from the taxon page
            prototype. Development only.
          </:subtitle>
          <:actions>
            <.button phx-click={show_modal("gallery-modal")}>Open a dialog</.button>
            <.compare_button navigate={~p"/species/shumardii/compare"} />
          </:actions>
        </.header>

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
              <.button disabled>Mark written</.button>
              <.compare_button navigate={~p"/species/coccinea"} />
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
            <:note>Jeff first, other sources behind</:note>
          </.section_heading>
          <.table id="field-marks-table" rows={@traits} row_id={&"trait-#{&1.trait}"} stack>
            <:col :let={t} label="Trait" row_header>{t.trait}</:col>
            <:col :let={t} label="Jeff Clark" voice>
              <%= if t.jeff do %>
                <% {quote, mark, href} = t.jeff %>
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
            <:item title="In running text">
              Two subgenera, <.sci_name name="Quercus" genus={nil} weight="regular" /> and
              <.sci_name name="Cerris" genus={nil} weight="regular" />.
            </:item>
            <:item title="Display size">
              <span class="text-[50px] leading-none"><.sci_name name="shumardii" /></span>
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
              <.taxonomy_band id="gallery-band-inline" label="Where it sits" inline>
                <:rank navigate={~p"/taxonomy"}><.sci_name name="Quercus" /></:rank>
                <:rank navigate={~p"/taxonomy/Quercus"} rank="subg.">
                  <.sci_name name="Quercus" />
                </:rank>
                <:rank navigate={~p"/taxonomy/Quercus/Lobatae"} rank="sect.">
                  <.sci_name name="Lobatae" genus={nil} />
                </:rank>
                <:rank navigate={~p"/taxonomy/Quercus/Lobatae/Coccineae"} rank="subsect.">
                  <.sci_name name="Coccineae" genus={nil} />
                </:rank>
              </.taxonomy_band>
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
          <.section_heading id="page">
            Page<:note>column, read, form and frame widths; the head; the bleed</:note>
          </.section_heading>
          <p class="max-w-[68ch]">
            This gallery is a <code>page</code> at the frame: the band above runs in its bleed, the
            window's full width, and everything else sits in the 1400px frame, which only pages that
            set columns side by side take (the source comparison, a merge). Every single-column page
            sits in one centred 960px column: lists, taxon pages and records take column; prose takes
            read and forms and account pages take form, which hold the content under the head to
            their measure from the column's left edge. The head spans the column.
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
      </.page>
    </main>

    <.modal id="gallery-modal">
      <:title>Discard your changes?</:title>
      <p class="max-w-[60ch]">
        The edits to <i>Quercus shumardii</i> since you last saved will be lost.
      </p>
      <:actions>
        <.button phx-click={JS.exec("data-cancel", to: "#gallery-modal")}>Keep editing</.button>
        <.button variant="primary" phx-click={JS.exec("data-cancel", to: "#gallery-modal")}>
          Discard changes
        </.button>
      </:actions>
    </.modal>
    """
  end

  @impl true
  def handle_event("noop", _params, socket), do: {:noreply, socket}

  defmodule NotAvailable do
    @moduledoc false
    defexception message: "the component gallery is a dev route", plug_status: 404
  end
end
