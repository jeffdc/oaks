defmodule OaksWeb.DesignComponents do
  @moduledoc """
  Content components of the DESIGN.md system: the taxonomy band, section
  headings, source marks, standing marks, the status tag, the Compare
  button and the other-sources disclosure of the field-marks table.

  Imported into every LiveView and HTML module (see `OaksWeb`). The
  generic pieces (button, header, ruled table, list, modal, flash, input)
  are in `OaksWeb.CoreComponents`. CSS: `assets/css/system/components.css`.
  `/dev/components` shows every component (dev only).

  The rules these components keep:

    * Scientific names are italic in the serif; rank words, authorities and
      the hybrid sign stay roman. Callers wrap names in `<i>`.
    * Jeff's words appear in curly quotes and are followed by a
      `source_mark/1`, every time.
    * Agree, differs and unreviewed are drawn marks (`standing_mark/1`),
      never colours.
  """
  use Phoenix.Component

  import OaksWeb.CoreComponents, only: [button: 1]

  alias Phoenix.LiveView.JS

  @doc """
  Renders the taxonomy band: the ochre field holding the breadcrumb, every
  rank linked and separated by drawn chevrons, the current taxon last. It
  sits in the same place on every taxon page.

  Each `:rank` takes `navigate` (or `href`) and an optional `rank` word
  ("subg.", "sect.", "subsect.", "complex"), shown roman before the name,
  or after it with `rank_after`. Wrap the name itself in `<i>`.

  The optional `:siblings` slot adds the menu at the band's right end; its
  `label` reads like "Coccineae · 7 species" and its content is `<li>`
  items, the current taxon as `<span aria-current="page">`. A click
  outside or Esc closes it.

  On phones the path is one scrolling line, scrolled to the current taxon
  (the PinCurrentTaxon hook in assets/js/app.js) and fading at its left
  edge.

  ## Examples

      <.taxonomy_band>
        <:rank navigate={~p"/taxonomy/Quercus"}><i>Quercus</i></:rank>
        <:rank navigate={~p"/taxonomy/Quercus/Lobatae"} rank="sect."><i>Lobatae</i></:rank>
        <:current><i>Q. shumardii</i></:current>
      </.taxonomy_band>
  """
  attr :id, :string, default: "taxonomy-band"
  attr :label, :string, default: "Taxonomy", doc: "the nav's accessible name"
  attr :class, :any, default: nil

  slot :rank, doc: "a linked rank, outermost first" do
    attr :navigate, :string
    attr :href, :string
    attr :rank, :string, doc: "the rank word, set roman"
    attr :rank_after, :boolean, doc: "show the rank word after the name (complex)"
  end

  slot :current, required: true, doc: "the current taxon"

  slot :siblings, doc: "the siblings menu" do
    attr :label, :string, required: true
  end

  def taxonomy_band(assigns) do
    ~H"""
    <nav id={@id} class={["oc-band", @class]} aria-label={@label}>
      <div class="oc-band-in">
        <ol id={"#{@id}-path"} phx-hook="PinCurrentTaxon">
          <li :for={rank <- @rank}>
            <.link navigate={rank[:navigate]} href={rank[:href]}>
              <span :if={rank[:rank] && !rank[:rank_after]} class="oc-band-rk">{rank.rank}</span>
              {render_slot(rank)}
              <span :if={rank[:rank] && rank[:rank_after]} class="oc-band-rk">{rank.rank}</span>
            </.link>
          </li>
          <li><span aria-current="page">{render_slot(@current)}</span></li>
        </ol>
        <details
          :for={siblings <- @siblings}
          id={"#{@id}-siblings"}
          phx-click-away={JS.remove_attribute("open", to: "##{@id}-siblings")}
          phx-window-keydown={JS.remove_attribute("open", to: "##{@id}-siblings")}
          phx-key="Escape"
        >
          <summary>{siblings.label}</summary>
          <ul class="oc-band-siblings">{render_slot(siblings)}</ul>
        </details>
      </div>
    </nav>
    """
  end

  @doc """
  Renders a section heading: an uppercase Archivo label standing on a 2px
  ink rule, with an optional note at the right (a count, a short aside).

  ## Examples

      <.section_heading id="field-marks">Field marks</.section_heading>
      <.section_heading>Look-alikes<:note>3 taxa</:note></.section_heading>
  """
  attr :id, :string, default: nil
  attr :level, :string, values: ~w(h2 h3), default: "h2"
  attr :class, :any, default: nil
  slot :inner_block, required: true
  slot :note

  def section_heading(assigns) do
    ~H"""
    <.dynamic_tag tag_name={@level} id={@id} class={["oc-section-heading", @class]}>
      <span>{render_slot(@inner_block)}</span>
      <small :if={@note != []} class="oc-section-heading-note">{render_slot(@note)}</small>
    </.dynamic_tag>
    """
  end

  @doc """
  Renders a source mark: the pencil-blue link that follows every quote of
  Jeff's and every sourced value. Without `href` or `navigate` it renders
  as plain text in the same style, for a source with no page yet.

  ## Examples

      <q>buds looks glabrous and pretty small.</q>
      <.source_mark href="https://www.inaturalist.org/observations/190127456">i465271504</.source_mark>
  """
  attr :href, :string, default: nil
  attr :navigate, :string, default: nil
  attr :title, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def source_mark(%{href: nil, navigate: nil} = assigns) do
    ~H"""
    <span class={["oc-src", @class]} title={@title}>{render_slot(@inner_block)}</span>
    """
  end

  def source_mark(assigns) do
    ~H"""
    <.link class={["oc-src", @class]} href={@href} navigate={@navigate} title={@title}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Renders a standing mark: a drawn 14px mark and its label.

    * `agree`: a ticked open circle.
    * `differs`: a filled square carrying a not-equal sign; sources disagree.
    * `open`: a dashed open circle; unreviewed or not recorded.

  The label carries the meaning in words; the mark is hidden from
  assistive technology.

  ## Examples

      <.standing_mark standing="agree">Oaks of the World agrees</.standing_mark>
      <.standing_mark standing="differs">Sibley differs on size</.standing_mark>
      <.standing_mark standing="open">2 sources, not reviewed</.standing_mark>
  """
  attr :standing, :string, required: true, values: ~w(agree differs open)
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def standing_mark(assigns) do
    ~H"""
    <span class={["oc-mk", @class]} data-standing={@standing}>
      <.mark_svg standing={@standing} />
      <span>{render_slot(@inner_block)}</span>
    </span>
    """
  end

  attr :standing, :string, required: true

  defp mark_svg(%{standing: "agree"} = assigns) do
    ~H"""
    <svg viewBox="0 0 14 14" aria-hidden="true">
      <circle cx="7" cy="7" r="6" fill="none" stroke="currentColor" stroke-width="1.6" />
      <path d="M4 7.2 6.1 9.3 10 4.9" fill="none" stroke="currentColor" stroke-width="1.8" />
    </svg>
    """
  end

  defp mark_svg(%{standing: "differs"} = assigns) do
    ~H"""
    <svg viewBox="0 0 14 14" aria-hidden="true">
      <rect x="0.75" y="0.75" width="12.5" height="12.5" fill="currentColor" />
      <path class="oc-mk-cut" d="M3.6 5.4h6.8M3.6 8.6h6.8" stroke-width="1.5" />
      <path class="oc-mk-cut" d="M9.2 2.9 4.8 11.1" stroke-width="1.6" stroke-linecap="square" />
    </svg>
    """
  end

  defp mark_svg(%{standing: "open"} = assigns) do
    ~H"""
    <svg viewBox="0 0 14 14" aria-hidden="true">
      <circle
        cx="7"
        cy="7"
        r="6"
        fill="none"
        stroke="currentColor"
        stroke-width="1.6"
        stroke-dasharray="2.2 1.8"
      />
    </svg>
    """
  end

  @doc """
  Renders a row of standing marks, as a legend or a mark strip.

  ## Examples

      <.standing_marks>
        <.standing_mark standing="agree">agrees</.standing_mark>
        <.standing_mark standing="differs">differs</.standing_mark>
      </.standing_marks>
  """
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def standing_marks(assigns) do
    ~H"""
    <div class={["oc-marks", @class]}>{render_slot(@inner_block)}</div>
    """
  end

  @doc """
  Renders a status tag: an outlined ink stamp, such as a conservation
  status. Follow it with a `source_mark/1`.

  ## Examples

      <.status_tag title="IUCN Red List: Least Concern">IUCN LC</.status_tag>
      <.source_mark href="#sources">IUCN 2024-2</.source_mark>
  """
  attr :title, :string, default: nil, doc: "the status spelled out"
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def status_tag(assigns) do
    ~H"""
    <span class={["oc-status", @class]} title={@title}>{render_slot(@inner_block)}</span>
    """
  end

  @doc """
  Renders the Compare button: ochre, square, ink-outlined; hover inverts it
  to ochre on ink. It opens the side-by-side comparison with a look-alike.

  ## Examples

      <.compare_button patch={~p"/species/shumardii?vs=rubra"} />
      <.compare_button navigate={@path}>Compare with <i>Q. rubra</i></.compare_button>
  """
  attr :rest, :global, include: ~w(href navigate patch)
  attr :class, :any, default: nil
  slot :inner_block

  def compare_button(assigns) do
    ~H"""
    <.button variant="primary" size="compact" class={@class} {@rest}>
      {if @inner_block != [], do: render_slot(@inner_block), else: "Compare"}
    </.button>
    """
  end

  @doc """
  Renders other sources behind a disclosure, as in the field-marks table:
  the summary is a standing mark, and opening it shows each source's text
  as that source wrote it, with its attribution beneath.

  ## Examples

      <.other_sources standing="differs" summary="Sibley differs on size">
        <:source by="Sibley Guide to Trees">large, grayish or straw-colored, and hairless</:source>
      </.other_sources>
  """
  attr :standing, :string, required: true, values: ~w(agree differs open)
  attr :summary, :string, required: true
  attr :open, :boolean, default: false

  slot :source, required: true do
    attr :by, :string, required: true
  end

  def other_sources(assigns) do
    ~H"""
    <details class="oc-other" open={@open}>
      <summary>
        <.standing_mark standing={@standing}>{@summary}</.standing_mark>
      </summary>
      <p :for={source <- @source}>
        {render_slot(source)}<span class="oc-by">{source.by}</span>
      </p>
    </details>
    """
  end

  @doc """
  Renders the empty statement for a field with no general statement:
  "No statement yet" in italic ink-3. Missing is empty; nothing is filled in.
  """
  slot :inner_block

  def no_statement(assigns) do
    ~H"""
    <span class="oc-empty">
      {if @inner_block != [], do: render_slot(@inner_block), else: "No statement yet"}
    </span>
    """
  end
end
