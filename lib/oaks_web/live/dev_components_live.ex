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
    <.taxonomy_band>
      <:rank navigate={~p"/taxonomy"}><i>Quercus</i></:rank>
      <:rank navigate={~p"/taxonomy/Quercus"} rank="subg."><i>Quercus</i></:rank>
      <:rank navigate={~p"/taxonomy/Quercus/Lobatae"} rank="sect."><i>Lobatae</i></:rank>
      <:rank navigate={~p"/taxonomy/Quercus/Lobatae/Coccineae"} rank="subsect.">
        <i>Coccineae</i>
      </:rank>
      <:rank navigate={~p"/species/shumardii"} rank="complex" rank_after><i>shumardii</i></:rank>
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

    <main id="main-content" class="mx-auto max-w-frame px-s6 pt-s6 pb-s8 max-md:px-s4">
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
