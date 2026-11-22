defmodule OaksWeb.DesignComponents do
  @moduledoc """
  Content components of the DESIGN.md system: scientific names, the
  taxonomy band, section headings, source marks, standing marks, the
  status tag (and its IUCN Red List variant), the Compare button, the
  other-sources disclosure of the field-marks table, and the centred
  pieces of the home page (the title page, chapter headings, the contents
  list, the specimen and the colophon).

  Imported into every LiveView and HTML module (see `OaksWeb`). The
  generic pieces (button, header, ruled table, list, modal, flash, input)
  are in `OaksWeb.CoreComponents`. CSS: `assets/css/system/components.css`.
  `/dev/components` shows every component (dev only).

  The rules these components keep:

    * Scientific names are italic in the serif; rank words, authorities and
      the hybrid sign stay roman. Every name goes through `sci_name/1`.
    * Jeff's words appear in curly quotes and are followed by a
      `source_mark/1`, every time.
    * Agree, differs and unreviewed are drawn marks (`standing_mark/1`),
      never colours. IUCN status (`iucn_status/1`) is the one categorical
      colour code, and always shows its code with the colour.
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

  With `inline`, the band is an ochre plate the width of its path rather
  than a full-width field, and it wraps rather than scrolls: for showing
  where a taxon sits away from its own page (the home page's oak at
  random). There `:current` is optional; leave it out when the taxon is
  named beside the band.

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
  attr :inline, :boolean, default: false, doc: "a plate the width of its path, wrapping"

  slot :rank, doc: "a linked rank, outermost first" do
    attr :navigate, :string
    attr :href, :string
    attr :rank, :string, doc: "the rank word, set roman"
    attr :rank_after, :boolean, doc: "show the rank word after the name (complex)"
  end

  slot :current, doc: "the current taxon (required unless inline)"

  slot :siblings, doc: "the siblings menu" do
    attr :label, :string, required: true
  end

  def taxonomy_band(assigns) do
    ~H"""
    <nav id={@id} class={["oc-band", @inline && "oc-band-inline", @class]} aria-label={@label}>
      <div class="oc-band-in">
        <ol id={"#{@id}-path"} phx-hook={if @inline, do: nil, else: "PinCurrentTaxon"}>
          <li :for={rank <- @rank}>
            <.link navigate={rank[:navigate]} href={rank[:href]}>
              <span :if={rank[:rank] && !rank[:rank_after]} class="oc-band-rk">{rank.rank}</span>
              {render_slot(rank)}
              <span :if={rank[:rank] && rank[:rank_after]} class="oc-band-rk">{rank.rank}</span>
            </.link>
          </li>
          <li :if={@current != []}><span aria-current="page">{render_slot(@current)}</span></li>
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

  @rank_words ~w(subsp. ssp. var. subvar. f. nothosubsp. nothovar. subg. sect. subsect. ser.)

  @doc """
  Renders a scientific name, the one way names are set anywhere on the
  site (DESIGN.md, the Botanical Italic Rule).

  The name is italic in the serif: the genus at weight 400 and the
  epithets at 600 (`weight="regular"` sets them all at 400, for names in
  running text). The hybrid sign stays roman and spaced (`Quercus ×
  raineri`), and so do rank words (`var.`, `subsp.`, `sect.` ...). The
  author follows in roman ink-3. The size comes from the surrounding text.

  `name` is the name as stored: an epithet (`"alba"`), a named hybrid with
  or without its sign (`"× raineri"`, `"×bebbiana"`), a formula
  (`"agrifolia × parvula"`), an infraspecific name (`"agrifolia
  oxyadenia"`, `"alba var. latiloba"`) or a full name with its genus
  (`"Quercus alba"`, `"Q. alba"`). The genus is added unless the name
  carries one or `genus={nil}`.

  For a name above species (a subgenus, section or subsection), pass
  `rank` and the bare name: `<.sci_name name="Lobatae" rank="sect." />`
  renders "sect. *Lobatae*" with no genus. `genus={nil}` renders a bare
  uninomial. The hybrid sign is held to the words on both sides, so a
  formula name never breaks across lines.

  ## Examples

      <.sci_name name="alba" author="L." />
      <.sci_name name={s.scientific_name} hybrid={s.is_hybrid} abbreviate />
      <.sci_name name="Cerris" genus={nil} weight="regular" />
      <.sci_name name="Albae" rank="subsect." />
  """
  attr :name, :string, required: true, doc: "the name as stored"
  attr :hybrid, :boolean, default: false, doc: "a named hybrid stored without its sign"
  attr :genus, :any, default: "Quercus", doc: "the genus to add (a string), or nil for none"
  attr :abbreviate, :boolean, default: false, doc: "abbreviate the genus (Q.)"
  attr :rank, :string, default: nil, doc: "a rank word before a name above species"
  attr :author, :string, default: nil, doc: "the authority, set roman after the name"
  attr :weight, :string, values: ~w(epithet regular), default: "epithet"
  attr :class, :any, default: nil

  def sci_name(assigns) do
    assigns = assign(assigns, :parts, sci_name_parts(assigns))

    ~H"""
    <span class={["oc-sci", @weight == "regular" && "oc-sci-regular", @class]}>{@parts}</span>
    """
  end

  # The name as one run of escaped HTML, so no template whitespace falls
  # between its parts: genus, rank words, signs and epithets joined by
  # spaces (no-break after a rank word and on both sides of the hybrid
  # sign, so a formula never splits and no line starts or ends on one).
  defp sci_name_parts(assigns) do
    {genus, words} = split_genus(assigns)

    rank = if assigns.rank, do: [{:roman, assigns.rank}], else: []
    genus = if genus, do: [{:genus, genus}], else: []
    tokens = genus ++ rank ++ Enum.map(words, &word_token/1)

    Phoenix.HTML.raw([join_tokens(tokens), author_html(assigns.author)])
  end

  defp word_token(w) when w in ["×", "x"], do: {:sign, "×"}
  defp word_token(w) when w in @rank_words, do: {:roman, w}
  defp word_token(w), do: {:epithet, w}

  defp author_html(author) when author in [nil, ""], do: []

  defp author_html(author),
    do: [" ", ~s(<span class="oc-sci-a">), escape(author), "</span>"]

  # {genus or nil, the words after it}.
  defp split_genus(%{name: name, rank: rank}) when is_binary(rank) do
    {nil, words(String.trim(name))}
  end

  defp split_genus(%{name: name} = assigns) do
    case stated_genus(String.trim(name)) do
      {nil, ""} ->
        {nil, []}

      # The genus on its own is a uninomial, set like any other name.
      {genus, ""} ->
        {nil, [genus]}

      {genus, rest} ->
        {genus_label(genus || assigns.genus, assigns.abbreviate),
         rest_words(rest, assigns.hybrid)}
    end
  end

  defp stated_genus(name) do
    case Regex.run(~r/^(Quercus|Q\.)(?:\s+(.*))?$/u, name) do
      [_, _genus | rest] -> {"Quercus", Enum.join(rest)}
      nil -> {nil, name}
    end
  end

  defp genus_label(nil, _abbreviate), do: nil
  defp genus_label(genus, true), do: String.first(genus) <> "."
  defp genus_label(genus, _abbreviate), do: genus

  defp rest_words(rest, hybrid), do: rest |> OaksWeb.SpeciesName.label(hybrid) |> words()

  defp words(text) do
    text |> String.split(~r/\s+/u, trim: true) |> split_attached_sign()
  end

  # "×bebbiana" inside a name reads as the sign and the epithet.
  defp split_attached_sign(words) do
    Enum.flat_map(words, fn
      "×" <> rest when rest != "" -> ["×", rest]
      w -> [w]
    end)
  end

  defp join_tokens(tokens) do
    tokens
    |> Enum.with_index()
    |> Enum.map(fn {{kind, text}, i} ->
      sep =
        cond do
          i == 0 -> ""
          elem(Enum.at(tokens, i - 1), 0) in [:roman, :sign] -> "\u00A0"
          kind == :sign -> "\u00A0"
          true -> " "
        end

      [sep, token_html(kind, text)]
    end)
  end

  defp token_html(:genus, text), do: [~s(<i class="oc-sci-g">), escape(text), "</i>"]
  defp token_html(:epithet, text), do: [~s(<i class="oc-sci-e">), escape(text), "</i>"]
  defp token_html(:roman, text), do: [~s(<span class="oc-sci-r">), escape(text), "</span>"]
  defp token_html(:sign, text), do: [~s(<span class="oc-sci-x">), escape(text), "</span>"]

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

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
  Renders a status tag: an outlined ink stamp, such as a draft marker or
  a source type. Follow it with a `source_mark/1` when it is sourced. For a
  conservation status use `iucn_status/1`, which builds on it.

  ## Examples

      <.status_tag class="border-dashed uppercase">Draft</.status_tag>
      <.status_tag title="HTTP status 404">Error 404</.status_tag>
  """
  attr :title, :string, default: nil, doc: "the status spelled out"
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def status_tag(assigns) do
    ~H"""
    <span class={["oc-status", @class]} title={@title}>{render_slot(@inner_block)}</span>
    """
  end

  @iucn_categories %{
    "EX" => "Extinct",
    "EW" => "Extinct in the Wild",
    "CR" => "Critically Endangered",
    "EN" => "Endangered",
    "VU" => "Vulnerable",
    "NT" => "Near Threatened",
    "LC" => "Least Concern",
    "DD" => "Data Deficient",
    "NE" => "Not Evaluated"
  }

  @doc """
  Returns the IUCN Red List category a code stands for ("LC" is "Least
  Concern"), or nil for a code that isn't one.
  """
  @spec iucn_category(String.t() | nil) :: String.t() | nil
  def iucn_category(code), do: Map.get(@iucn_categories, code)

  @doc """
  Renders an IUCN Red List status: a `status_tag/1` filled with the
  category's conventional Red List colour, the one categorical colour code
  DESIGN.md allows (decision 5604). The code always shows with the colour;
  the category is spelled out in the title and for screen readers.

  With `prefix={false}` (a list row) "IUCN" is read by screen readers but
  not shown. A code that isn't a Red List category renders as the plain
  stamp.

  ## Examples

      <.iucn_status code="LC" />
      <.source_mark href="#sources">IUCN 2024-2</.source_mark>

      <.iucn_status code={@species.conservation_status} prefix={false} />
  """
  attr :code, :string, required: true, doc: "the Red List code, such as LC"
  attr :prefix, :boolean, default: true, doc: "show IUCN before the code"
  attr :class, :any, default: nil

  def iucn_status(assigns) do
    assigns = assign(assigns, :category, iucn_category(assigns.code))

    ~H"""
    <.status_tag
      class={[@category && "oc-iucn oc-iucn-#{String.downcase(@code)}", @class]}
      title={@category && "IUCN Red List: #{@category}"}
    >
      {if @prefix, do: "IUCN "}<span :if={!@prefix} class="sr-only">IUCN </span>{@code}<span
        :if={@category}
        class="sr-only"
      >: {@category}</span>
    </.status_tag>
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

  @doc """
  Renders the title page: the masthead's ink continued as a field holding
  the title and its subtitle, centred, at display size. The ink ends in a
  6px ochre edge that runs through the middle of the search field, so the
  field hangs across it, half on ink and half on paper. The `:count` items
  sit on paper below it, separated by small ink squares.

  The title is set in the serif roman, in paper; an `<em>` in it is set in
  ochre italic. Put it in a page's `:bleed` slot so the ink spans the
  window. Without `search` there is no field and the ink ends at its edge.

  ## Examples

      <.title_page search={~p"/search"}>
        Oak <em>Compendium</em>
        <:subtitle>Oaks, their varieties and their hybrids, and how to tell them apart</:subtitle>
        <:count>494 species</:count>
        <:count>238 hybrids</:count>
      </.title_page>
  """
  attr :id, :string, default: "title-page"
  attr :search, :string, default: nil, doc: "the search form's action; nil for no field"
  attr :search_label, :string, default: "Find an oak"
  attr :search_placeholder, :string, default: "Name, common name or synonym"
  slot :inner_block, required: true, doc: "the title"
  slot :subtitle
  slot :count, doc: "a count set on paper under the search"

  def title_page(assigns) do
    ~H"""
    <section id={@id} class="oc-tp" aria-labelledby={"#{@id}-title"}>
      <div class="oc-tp-ink">
        <div class="oc-tp-in">
          <h1 id={"#{@id}-title"} class="oc-tp-title">{render_slot(@inner_block)}</h1>
          <p :if={@subtitle != []} class="oc-tp-sub">{render_slot(@subtitle)}</p>
        </div>
      </div>
      <div :if={@search} class="oc-tp-edge">
        <form action={@search} method="get" role="search" class="oc-tp-search">
          <label for={"#{@id}-q"} class="sr-only">{@search_label}</label>
          <input
            type="search"
            id={"#{@id}-q"}
            name="q"
            placeholder={@search_placeholder}
            autocomplete="off"
            spellcheck="false"
          />
          <button type="submit">Find</button>
        </form>
      </div>
      <div :if={!@search} class="oc-tp-edge oc-tp-edge-plain"></div>
      <p :if={@count != []} class="oc-tp-counts">
        <span :for={count <- @count}>{render_slot(count)}</span>
      </p>
    </section>
    """
  end

  @doc """
  Renders a chapter heading: a large serif italic heading, centred, for
  the parts of a centred page (the home page's Contents, An oak at
  random). With `mark` the acorn stands beside it, the masthead's mark set
  on paper.

  ## Examples

      <.chapter_heading id="contents-heading" mark>Contents</.chapter_heading>
  """
  attr :id, :string, default: nil
  attr :mark, :boolean, default: false, doc: "set the acorn beside the heading"
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def chapter_heading(assigns) do
    ~H"""
    <h2 id={@id} class={["oc-chapter", @class]}>
      <svg :if={@mark} viewBox="0 0 24 24" aria-hidden="true" focusable="false">
        <path class="oc-chapter-cap" d="M5 9.5C5 6 8 4 12 4s7 2 7 5.5H5Z" />
        <path class="oc-chapter-nut" d="M6.5 10.5h11c0 5-2.5 9-5.5 9.5-3-.5-5.5-4.5-5.5-9.5Z" />
        <path class="oc-chapter-stem" d="M12 1.5v2.5" />
      </svg>
      <span>{render_slot(@inner_block)}</span>
    </h2>
    """
  end

  @doc """
  Renders a contents list: the parts of the site in two ruled columns
  (one on phones) under a 2px ink rule, each part's name in the serif with
  its count at the right and one line about it beneath. The whole row is
  the link. A part with no `navigate` isn't built yet: it is not a link
  and carries its `status` (such as "In preparation") as a dashed stamp
  where the count would be.

  ## Examples

      <.chapter_heading id="contents-heading" mark>Contents</.chapter_heading>
      <.contents labelledby="contents-heading">
        <:entry title="Species" navigate={~p"/species"} count={494}>
          Every oak, A to Z.
        </:entry>
        <:entry title="Taxonomy" navigate={~p"/taxonomy"} count={8} count_label="sections">
          Two subgenera, their sections and subsections.
        </:entry>
        <:entry title="Identify" status="In preparation">
          A trait filter that narrows the oaks by what you can see.
        </:entry>
      </.contents>
  """
  attr :id, :string, default: "contents"
  attr :labelledby, :string, default: nil, doc: "the id of the list's heading"

  slot :entry, required: true, doc: "a part of the site; its content is one line about it" do
    attr :title, :string, required: true
    attr :navigate, :string, doc: "the part's page; leave out for a part not built yet"
    attr :count, :any, doc: "a count shown at the right"
    attr :count_label, :string, doc: "a word after the count, such as sections"
    attr :status, :string, doc: "a stamp for a part not built yet"
  end

  def contents(assigns) do
    ~H"""
    <nav id={@id} class="oc-contents" aria-labelledby={@labelledby}>
      <ol>
        <li :for={entry <- @entry}>
          <.contents_row entry={entry} />
        </li>
      </ol>
    </nav>
    """
  end

  attr :entry, :map, required: true

  defp contents_row(%{entry: %{navigate: navigate}} = assigns) when is_binary(navigate) do
    ~H"""
    <.link navigate={@entry.navigate} class="oc-contents-row">
      <.contents_parts entry={@entry} />
    </.link>
    """
  end

  defp contents_row(assigns) do
    ~H"""
    <div class="oc-contents-row oc-contents-off">
      <.contents_parts entry={@entry} />
    </div>
    """
  end

  attr :entry, :map, required: true

  defp contents_parts(assigns) do
    ~H"""
    <span class="oc-contents-title">{@entry.title}</span>
    <span class="oc-contents-count">
      <%= cond do %>
        <% @entry[:count] != nil -> %>
          {@entry.count}<small :if={@entry[:count_label]}>{@entry.count_label}</small>
        <% @entry[:status] -> %>
          <.status_tag class="border-dashed uppercase">{@entry.status}</.status_tag>
        <% true -> %>
      <% end %>
    </span>
    <span class="oc-contents-about">{render_slot(@entry)}</span>
    """
  end

  @doc """
  Renders a specimen: one taxon set large and centred under a chapter
  heading, as the home page's oak at random. The name is in display type,
  then the authority, where it sits (`:band`, an inline `taxonomy_band/1`),
  a line about it (`:about`, such as its hybrids) and the actions.

  With `loading` it holds the section's place at about its usual height
  and announces nothing, so the page doesn't jump when the taxon arrives
  after the live connection.

  ## Examples

      <.specimen id="oak-at-random" heading="An oak at random">
        <:name><.sci_name name="michauxii" /></:name>
        <:author>Nutt.</:author>
        <:band><.taxonomy_band id="b" inline>...</.taxonomy_band></:band>
        <:about>Hybrids ...</:about>
        <:actions><.button phx-click="shuffle">Show another</.button></:actions>
      </.specimen>
  """
  attr :id, :string, required: true
  attr :heading, :string, required: true
  attr :loading, :boolean, default: false
  slot :name
  slot :author
  slot :band
  slot :about
  slot :actions

  def specimen(assigns) do
    ~H"""
    <section
      id={@id}
      class="oc-specimen"
      aria-labelledby={"#{@id}-heading"}
      aria-busy={@loading && "true"}
    >
      <.chapter_heading id={"#{@id}-heading"}>{@heading}</.chapter_heading>
      <div :if={@loading} class="oc-specimen-wait"></div>
      <%= if !@loading do %>
        <p class="oc-specimen-name">{render_slot(@name)}</p>
        <p :if={@author != []} class="oc-specimen-author">{render_slot(@author)}</p>
        <div :if={@band != []} class="oc-specimen-band">{render_slot(@band)}</div>
        <p :if={@about != []} class="oc-specimen-about">{render_slot(@about)}</p>
        <div :if={@actions != []} class="oc-specimen-actions">{render_slot(@actions)}</div>
      <% end %>
    </section>
    """
  end

  @doc """
  Renders a colophon: a short centred list closing a centred page, such
  as the sources behind the home page, under a small label on a hairline.
  The items run as one line separated by slashes, one per line on phones.

  ## Examples

      <.colophon id="home-sources" label="Sources">
        <:item><.link navigate={~p"/sources/3"}>Oak Compendium</.link></:item>
        <:item><.link navigate={~p"/sources/2"}>Oaks of the World</.link></:item>
      </.colophon>
  """
  attr :id, :string, required: true
  attr :label, :string, required: true
  slot :item, required: true

  def colophon(assigns) do
    ~H"""
    <section id={@id} class="oc-colophon" aria-labelledby={"#{@id}-label"}>
      <h2 id={"#{@id}-label"}>{@label}</h2>
      <ul>
        <li :for={item <- @item}>{render_slot(item)}</li>
      </ul>
    </section>
    """
  end

  @doc """
  Renders a work's title, such as a source's name, with the genus
  *Quercus* in it set as a scientific name (the Botanical Italic Rule).
  The rest of the title is as stored.

  ## Examples

      <.work_title title="Notes on North American Trees. I. Quercus" />
  """
  attr :title, :string, required: true

  def work_title(assigns) do
    # One run of escaped HTML, so no template whitespace falls beside the
    # name; the name is set as sci_name/1 sets a uninomial at 400.
    html =
      ~r/\b(Quercus)\b/u
      |> Regex.split(assigns.title, include_captures: true)
      |> Enum.map(fn
        "Quercus" ->
          [~s(<span class="oc-sci oc-sci-regular">), token_html(:epithet, "Quercus"), "</span>"]

        part ->
          escape(part)
      end)

    assigns = assign(assigns, :html, Phoenix.HTML.raw(html))

    ~H"""
    {@html}
    """
  end
end
