defmodule OaksWeb.DesignComponents do
  @moduledoc """
  Content components of the DESIGN.md system: scientific names, the
  taxonomy band, section headings, source marks, standing marks, the
  status tag (and its IUCN Red List variant), the Compare button, the
  other-sources disclosure of the field-marks table, and the centred
  pieces of the home page (the title page, chapter headings, the contents
  list, the specimen and the colophon), and the error notice and the
  not-found page that `OaksWeb.ErrorHTML` shows.

  Imported into every LiveView and HTML module (see `OaksWeb`). The
  generic pieces (button, header, ruled table, list, modal, flash, input)
  are in `OaksWeb.CoreComponents`. CSS: `assets/css/system/components.css`.
  `/dev/components` shows every component (dev only).

  The rules these components keep:

    * Scientific names are italic in the serif; rank words, authorities and
      the hybrid sign stay roman. Every name goes through `sci_name/1`.
    * Oak Compendium's own text appears in curly quotes and is followed by a
      `source_mark/1`, every time.
    * Agree, differs and unreviewed are drawn marks (`standing_mark/1`),
      never colours. IUCN status (`iucn_status/1`) is the one categorical
      colour code, and always shows its code with the colour.
  """
  use Phoenix.Component
  use OaksWeb, :verified_routes

  import OaksWeb.CoreComponents, only: [button: 1, header: 1]

  alias Phoenix.LiveView.JS

  @doc """
  Renders the taxonomy band: the ochre field holding the breadcrumb, every
  rank linked and separated by drawn chevrons, the current taxon last. On
  a taxon page it goes in `page/1`'s `:bleed` slot, straight under the
  masthead: the same place, height and voice on every taxon page
  (taxonomy, species, hybrid, variety and comparison).

  The band sets every step itself, from data: pages pass `ranks` (the
  linked steps, from `OaksWeb.TaxonPath.ranks/1`) and `current` (a taxon
  step, or `OaksWeb.TaxonPath.current/1` for a species). Rank words
  (subg., sect., subsect.) stand roman before a name and "complex" after
  it; names are `sci_name/1` in the band's own voice, 16px with the
  current taxon's epithets at 700: genus to subsection bare, a complex
  and a species abbreviated (Q.).

  The path is one line at every width, so the band's height never
  changes. A path longer than the line (on phones, mostly) scrolls,
  pinned to the current taxon, fading at its left edge while steps are
  scrolled off there, with a thin scrollbar for a mouse (the
  PinCurrentTaxon hook in assets/js/app.js marks it `data-overflow` and
  `data-scrolled`).

  The optional `:siblings` slot adds the menu at the band's right end; its
  `label` reads like "Coccineae · 7 species" and its content is `<li>`
  items, the current taxon as `<span aria-current="page">`. A click
  outside or Esc closes it. No page uses it yet.

  With `inline`, the band is an ochre plate the width of its path rather
  than a full-width field, and it wraps rather than scrolls: for showing
  where a taxon sits away from its own page (the home page's oak at
  random). There `current` is optional; leave it out when the taxon is
  named beside the band.

  ## Examples

      <.page>
        <:bleed><.taxonomy_band ranks={@band_ranks} current={TaxonPath.current(@species)} /></:bleed>
        ...
      </.page>

      <.taxonomy_band
        ranks={[%{level: "genus", name: "Quercus", hybrid: false, path: ~p"/taxonomy"}]}
        current={%{level: "subgenus", name: "Cerris", hybrid: false}}
      />
  """
  attr :id, :string, default: "taxonomy-band"
  attr :label, :string, default: "Taxonomy", doc: "the nav's accessible name"
  attr :class, :any, default: nil
  attr :inline, :boolean, default: false, doc: "a plate the width of its path, wrapping"

  attr :ranks, :list,
    default: [],
    doc: "the linked steps, outermost first: maps with level, name, hybrid and path"

  attr :current, :map,
    default: nil,
    doc: "the current step (level, name, hybrid); required unless inline"

  slot :siblings, doc: "the siblings menu" do
    attr :label, :string, required: true
  end

  def taxonomy_band(assigns) do
    ~H"""
    <nav id={@id} class={["oc-band", @inline && "oc-band-inline", @class]} aria-label={@label}>
      <div class="oc-band-in">
        <ol id={"#{@id}-path"} phx-hook={if @inline, do: nil, else: "PinCurrentTaxon"}>
          <li :for={rank <- @ranks}>
            <.link navigate={rank.path}><.band_step step={rank} /></.link>
          </li>
          <li :if={@current}>
            <span aria-current="page"><.band_step step={@current} /></span>
          </li>
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

  @band_rank_words %{"subgenus" => "subg.", "section" => "sect.", "subsection" => "subsect."}

  # One step of the band: the rank word, then the name (a complex's word
  # after it). Every band on the site sets its steps here.
  attr :step, :map, required: true

  defp band_step(%{step: %{level: "species"}} = assigns) do
    ~H"""
    <.sci_name name={@step.name} hybrid={@step.hybrid} abbreviate />
    """
  end

  defp band_step(assigns) do
    assigns = assign(assigns, :rank, @band_rank_words[assigns.step.level])

    ~H"""
    <span :if={@rank} class="oc-band-rk">{@rank}</span>
    <.sci_name name={@step.name} level={@step.level} />
    <span :if={@step.level == "complex"} class="oc-band-rk">complex</span>
    """
  end

  @rank_words ~w(subsp. ssp. var. subvar. f. nothosubsp. nothovar. subg. sect. subsect. ser.)

  # Lower-case words that start an authority rather than continue the name:
  # a misapplied name ("texana auctores"), a garden name ("repanda hort").
  @authority_words ~w(auct auctt auctores auctorum hort sensu)

  @doc """
  Renders a scientific name, the one way names are set anywhere on the
  site (DESIGN.md, the Botanical Italic Rule). Pages never set a name, or
  its size, any other way.

  The name is italic in the serif: the genus at weight 400 and the
  epithets at 600 (`weight="regular"` sets them all at 400, for a name in
  running Archivo text or a quiet metadata line). The hybrid sign stays
  roman and spaced (`Quercus × raineri`), and so do rank words (`var.`,
  `subsp.`, `sect.` ...). The author follows in roman ink-3.

  `name` is the name as stored: an epithet (`"alba"`), a named hybrid with
  or without its sign (`"× raineri"`, `"×bebbiana"`), a formula
  (`"agrifolia × parvula"`), an infraspecific name (`"agrifolia
  oxyadenia"`, `"alba var. latiloba"`) or a full name with its genus
  (`"Quercus alba"`, `"Q. alba"`, or another genus, as a synonym may be:
  `"Cyclobalanopsis glauca"`). A stored name that carries its authority
  (`"candida Steud."`, `"texana auctores"`) is split at the first word that
  isn't a lower-case epithet, a rank word or the sign (or that is
  `auctores`, `hort` and the like), and the rest set as the author. The
  genus is added unless the name carries one or `genus={nil}`; a genus
  other than Quercus is always set in full, never abbreviated.

  For a name above species (a subgenus, section or subsection), pass
  `rank` and the bare name: `<.sci_name name="Lobatae" rank="sect." />`
  renders "sect. *Lobatae*" with no genus. `genus={nil}` renders a bare
  uninomial. For a taxon record, pass its `level` instead: a genus,
  subgenus, section or subsection is a bare uninomial, and a complex,
  named for its species, takes Q. (`<.sci_name name="coccinea"
  level="complex" />` renders "*Q. coccinea*"). The hybrid sign is held to the words on both sides, so a
  formula name never breaks across lines.

  ## Size: by the name's role, never by the page

    * no `size` (the default): the size of the text around it, for names
      in running text, dialogs, table cells and field values. In the taxonomy band the band sets its own voice (16px, the
      current taxon at 700).
    * `size="display"`: the name in a page's title row (the display size,
      clamp 34px to 50px, with the author at 22px).
    * `size="headline"`: a name heading a comparison column (26px, the
      author at 17px).
    * `size="title"`: a name that is itself an entry in a list (18px, the
      author at 15px): the species list, search results, a taxon's
      species, a species' hybrids and relatives, a source's species.
    * `size="meta"`: a name in an Archivo metadata line beside a list
      entry (`sect. Lobatae`, `subg. Cerris`): 14px, all at 400, the rank
      word in the frame face as in the band.

  ## Genus: Quercus, Q. or none

    * `Quercus` in full (the default): in a title row, at a name's first
      mention in a dialog or passage, and in a list whose entries each
      stand alone (the species list, search results, a taxon's species, a
      picker's results).
    * `abbreviate` (Q.): after the full name has been given on the same
      page or passage; in lists of names under a taxon or record named
      above them (a species' parents, hybrids, relatives and varieties, a
      source's species, the references on the merge page); in comparison
      column heads; for the current species in the taxonomy band; and for
      a complex, which is named for its species (Q. coccinea); and for a
      species' synonyms (`Q. candida Steud.`, a synonym in another genus
      in full: `Cyclobalanopsis glauca (Thunb.) Oerst.`), on the species
      page and the merge page's synonyms to add.
    * `genus={nil}` (none): names above species (subgenus, section,
      subsection); a hybrid's other parent after "with"; a stored value
      shown as entered (the merge page's field values).

  A name in a link underlines its name words, not its author, on hover.

  ## Examples

      <.sci_name name="alba" author="L." size="display" />
      <.sci_name name={s.scientific_name} hybrid={s.is_hybrid} size="title" />
      <.sci_name name={h.name} hybrid abbreviate size="title" />
      <.sci_name name="Cerris" genus={nil} weight="regular" />
      <.sci_name name="Albae" rank="subsect." />
  """
  attr :name, :string, required: true, doc: "the name as stored"
  attr :hybrid, :boolean, default: false, doc: "a named hybrid stored without its sign"
  attr :genus, :any, default: "Quercus", doc: "the genus to add (a string), or nil for none"
  attr :abbreviate, :boolean, default: false, doc: "abbreviate the genus (Q.)"
  attr :rank, :string, default: nil, doc: "a rank word before a name above species"

  attr :level, :string,
    default: nil,
    doc: "a taxon's level (genus to complex): no genus, or Q. for a complex"

  attr :author, :string, default: nil, doc: "the authority, set roman after the name"
  attr :weight, :string, values: ~w(epithet regular), default: "epithet"

  attr :size, :string,
    values: [nil, "display", "headline", "title", "meta"],
    default: nil,
    doc: "the name's role: nil takes the surrounding size"

  attr :class, :any, default: nil

  def sci_name(assigns) do
    assigns =
      assigns
      |> level_genus()
      |> then(&assign(&1, :parts, sci_name_parts(&1)))

    ~H"""
    <span class={[
      "oc-sci",
      @size && "oc-sci-#{@size}",
      @weight == "regular" && "oc-sci-regular",
      @class
    ]}>{@parts}</span>
    """
  end

  # A complex is named for its species (Q. coccinea); a taxon above it is a
  # bare uninomial.
  defp level_genus(%{level: "complex"} = assigns),
    do: assign(assigns, genus: "Quercus", abbreviate: true)

  defp level_genus(%{level: level} = assigns) when is_binary(level),
    do: assign(assigns, :genus, nil)

  defp level_genus(assigns), do: assigns

  # The name as one run of escaped HTML, so no template whitespace falls
  # between its parts: genus, rank words, signs and epithets joined by
  # spaces (no-break after a rank word, after Q. and on both sides of the
  # hybrid sign, so a formula never splits and no line starts or ends on one),
  # wrapped in .oc-sci-n, then the author.
  defp sci_name_parts(assigns) do
    {name, stored_author} = split_author(assigns.name)
    {genus, words} = split_genus(%{assigns | name: name})

    rank = if assigns.rank, do: [{:roman, assigns.rank}], else: []
    genus = if genus, do: [{:genus, genus}], else: []
    tokens = genus ++ rank ++ Enum.map(words, &word_token/1)

    Phoenix.HTML.raw([
      ~s(<span class="oc-sci-n">),
      join_tokens(tokens),
      "</span>",
      author_html(assigns.author || stored_author)
    ])
  end

  defp word_token(w) when w in ["×", "x"], do: {:sign, "×"}
  defp word_token(w) when w in @rank_words, do: {:roman, w}
  defp word_token(w), do: {:epithet, w}

  defp author_html(author) when author in [nil, ""], do: []

  defp author_html(author),
    do: [" ", ~s(<span class="oc-sci-a">), escape(author), "</span>"]

  # {the name, its stored authority or nil}. The first word is always the
  # name (a genus or a uninomial may be capitalised); after it, the
  # authority starts at the first word that isn't a lower-case epithet, a
  # rank word or the hybrid sign: "shumardii var. acerifolia E.J.Palmer
  # 1927" is {"shumardii var. acerifolia", "E.J.Palmer 1927"}.
  defp split_author(name) do
    [first | rest] =
      case String.split(String.trim(name), ~r/\s+/u, trim: true) do
        [] -> [""]
        words -> words
      end

    {name_words, author_words} = Enum.split_while(rest, &name_word?/1)
    author = if author_words == [], do: nil, else: Enum.join(author_words, " ")

    {Enum.join([first | name_words], " "), author}
  end

  defp name_word?(w) do
    w in ["×", "x"] or w in @rank_words or
      (w not in @authority_words and Regex.match?(~r/^×?\p{Ll}[\p{Ll}\d-]*$/u, w))
  end

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

  # {the genus the name states or nil, the rest}: Quercus or Q., or any
  # other capitalised first word (a synonym in Cyclobalanopsis).
  defp stated_genus(name) do
    case Regex.run(~r/^(Quercus|Q\.|\p{Lu}\p{Ll}+)(?:\s+(.*))?$/u, name) do
      [_, genus | rest] when genus in ["Quercus", "Q."] -> {"Quercus", Enum.join(rest)}
      [_, genus | rest] -> {genus, Enum.join(rest)}
      nil -> {nil, name}
    end
  end

  # Only Quercus, the site's own genus, is abbreviated: Q. reads at once,
  # where C. for Cyclobalanopsis would not.
  defp genus_label(nil, _abbreviate), do: nil
  defp genus_label("Quercus", true), do: "Q."
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
          # An abbreviated genus never ends a line apart from its epithet.
          Enum.at(tokens, i - 1) == {:genus, "Q."} -> "\u00A0"
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
  Renders a source mark: the pencil-blue link that follows every Oak
  Compendium quote and every sourced value. Without `href` or `navigate` it renders
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
  attr :rest, :global
  slot :name, required: true
  slot :author
  slot :band
  slot :about
  slot :actions

  def specimen(assigns) do
    ~H"""
    <section id={@id} class="oc-specimen" aria-labelledby={"#{@id}-heading"} {@rest}>
      <.chapter_heading id={"#{@id}-heading"}>{@heading}</.chapter_heading>
      <p class="oc-specimen-name">{render_slot(@name)}</p>
      <p :if={@author != []} class="oc-specimen-author">{render_slot(@author)}</p>
      <div :if={@band != []} class="oc-specimen-band">{render_slot(@band)}</div>
      <p :if={@about != []} class="oc-specimen-about">{render_slot(@about)}</p>
      <div :if={@actions != []} class="oc-specimen-actions">{render_slot(@actions)}</div>
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

  @doc """
  Renders an error notice: the title row with the status stamped on the
  title's line ("Error 404"), a sentence of what happened, an optional search
  form, then the ways on as buttons, Go back last. Ochre goes on the one
  next step, so give one action (or the search's button)
  `variant="primary"`.

  The 403 and 500 pages use it directly; the 404 is `not_found/1`. Set it
  inside a `page/1`: the error pages take the reading measure.

  ## Examples

      <.error_notice status="500" title="Something went wrong">
        The Compendium hit an error and couldn’t show this page.
        <:actions><.button href={~p"/"} variant="primary">Home</.button></:actions>
      </.error_notice>
  """
  attr :id, :string, default: nil
  attr :status, :string, required: true, doc: "the HTTP status, such as 404"
  attr :title, :string, required: true, doc: "the page's h1"
  attr :back, :string, default: nil, doc: "where Go back goes; nil for no Go back"
  slot :inner_block, required: true, doc: "what happened, one short passage"
  slot :search, doc: "a search form under the passage"
  slot :actions, required: true, doc: "the ways on; Go back follows them"

  def error_notice(assigns) do
    ~H"""
    <section id={@id} class="oc-error-notice">
      <.header>
        {@title}
        <:meta>
          <.status_tag title={"HTTP status #{@status}"}>Error {@status}</.status_tag>
        </:meta>
      </.header>

      <p class="max-w-[68ch] text-pretty">{render_slot(@inner_block)}</p>

      {render_slot(@search)}

      <div class="mt-s6 flex flex-wrap gap-s3">
        {render_slot(@actions)}
        <.button :if={@back} href={@back}>Go back</.button>
      </div>
    </section>
    """
  end

  # What each kind of not-found page says (the index it offers is
  # not_found_index/1).
  @not_found %{
    page: %{
      title: "Page not found",
      noun: "page",
      hint: "The address may be mistyped, or the page may have moved.",
      next: "Search for the oak you were after, or browse the species list."
    },
    species: %{
      title: "Species not found",
      noun: "species",
      hint: "The name may be misspelled, or the oak may not be in the Compendium yet.",
      next: "Search for it by its scientific or common name, or browse the species list."
    },
    taxon: %{
      title: "Taxon not found",
      noun: "taxon",
      hint: "A name in the address may be misspelled, or the group may have moved.",
      next: "Browse the taxonomy from the genus down, or search for the group by name."
    },
    source: %{
      title: "Source not found",
      noun: "source",
      hint: "The address may be mistyped, or the source may have been removed.",
      next: "Browse the sources, or search for the work by name."
    },
    article: %{
      title: "Article not found",
      noun: "article",
      hint: "The address may be mistyped, or the article may not be published yet.",
      next: "Browse the articles, or search the Compendium."
    }
  }

  @doc """
  The title of a not-found page of the given kind ("Species not found"):
  its h1, and its head title.
  """
  @spec not_found_title(atom()) :: String.t()
  def not_found_title(kind), do: Map.fetch!(@not_found, kind).title

  defp not_found_index(kind) when kind in [:page, :species], do: {"Species list", ~p"/species"}
  defp not_found_index(:taxon), do: {"Taxonomy", ~p"/taxonomy"}
  defp not_found_index(:source), do: {"Sources", ~p"/sources"}
  defp not_found_index(:article), do: {"Articles", ~p"/articles"}

  @doc """
  Renders a not-found page's content: an `error_notice/1` stamped 404,
  naming what was asked for (the address, so a typo shows), a short line
  on why, a search of the Compendium (the one ochre action) and the
  relevant index, then Home and Go back.

  It is only shown with a real 404. A LiveView that finds nothing at its
  address raises `OaksWeb.NotFoundError` with a `kind`, and
  `OaksWeb.ErrorHTML` renders this from it; an address with no route is
  `:page`. `kind` picks the wording and the index: `:page` and `:species`
  offer the species list, `:taxon` the taxonomy, `:source` the sources and
  `:article` the articles.

  ## Examples

      <.not_found kind={:species} path="/species/shumardi" query="shumardi" />
      <.not_found path="/no-such-page" back="https://oakcompendium.org/" />
  """
  attr :id, :string, default: "not-found", doc: "the notice's id, and its search field's prefix"
  attr :kind, :atom, values: [:page, :species, :taxon, :source, :article], default: :page
  attr :path, :string, default: nil, doc: "the address asked for; nil for \"this address\""
  attr :query, :string, default: nil, doc: "a search to fill in, such as the name asked for"
  attr :back, :string, default: nil, doc: "where Go back goes; nil for no Go back"

  def not_found(assigns) do
    {index_label, index_path} = not_found_index(assigns.kind)

    assigns =
      assign(assigns,
        copy: Map.fetch!(@not_found, assigns.kind),
        index_label: index_label,
        index_path: index_path
      )

    ~H"""
    <.error_notice id={@id} status="404" title={@copy.title} back={@back}>
      <%= if @path do %>
        There’s no {@copy.noun} at <span class="font-frame font-semibold wrap-anywhere lining-nums tabular-nums">{@path}</span>.
      <% else %>
        There’s no {@copy.noun} at this address.
      <% end %>
      {@copy.hint} {@copy.next}
      <:search>
        <form action={~p"/search"} method="get" role="search" class="mt-s6">
          <label for={"#{@id}-search"} class="oc-label">Search the Compendium</label>
          <div class="flex gap-s2">
            <input
              id={"#{@id}-search"}
              type="search"
              name="q"
              value={@query}
              class="oc-input min-w-0 flex-1"
              placeholder="Scientific or common name"
            />
            <.button type="submit" variant="primary">Search</.button>
          </div>
        </form>
      </:search>
      <:actions>
        <.button href={@index_path}>{@index_label}</.button>
        <.button href={~p"/"}>Home</.button>
      </:actions>
    </.error_notice>
    """
  end

  # -- Photo editing (the species page's Add photos and Manage photos
  # dialogs; docs/species-photos-plan.md, Phase 5) --

  @doc """
  Renders a grid of photos to pick from, three to a row, each a
  `photo_tile/1`: an iNaturalist observation's photos in the Add photos
  dialog. Pass `aria-live="polite"` while imports run, so their progress
  is read out.

  ## Examples

      <.photo_picker id="inat-photos">
        <:meta>janedoe · Blue Ridge, VA · 2026-05-04</:meta>
        <.photo_tile src={photo.thumbnail_url} label="Photo 1, CC-BY-NC" name="photo_ids[]" value={1}>
          CC-BY-NC
        </.photo_tile>
      </.photo_picker>
  """
  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global
  slot :meta, doc: "a line above the photos: the observation's observer, place, date and taxon"
  slot :inner_block, required: true

  def photo_picker(assigns) do
    ~H"""
    <div class={["oc-photo-pick", @class]}>
      <p :for={meta <- @meta} class="oc-photo-pick-meta">{render_slot(meta)}</p>
      <ul id={@id} {@rest}>{render_slot(@inner_block)}</ul>
    </div>
    """
  end

  @doc """
  Renders one photo of a `photo_picker/1`: a square thumbnail and, under
  it, its note (the license, a `status_tag/1` stamp, or a `photo_status/1`).

  With `name`, the tile is a checkbox labelled `label`, inked round when
  picked. Without it, the tile only shows the photo, `off` dims it (a photo
  already added) and its note may hold a button (Retry).

  ## Examples

      <.photo_tile src={url} label="Photo 4, All rights reserved" name="photo_ids[]" value={4}>
        <.status_tag>All rights reserved</.status_tag>
      </.photo_tile>

      <.photo_tile src={url} label="Photo 5" off>
        <.photo_status status="exists" />
      </.photo_tile>
  """
  attr :src, :string, default: nil, doc: "the thumbnail's URL; none draws an empty tile"
  attr :label, :string, required: true, doc: "names the photo, for the checkbox or the image"
  attr :name, :string, default: nil, doc: "the checkbox's name: the photo can be picked"
  attr :value, :any, default: nil
  attr :checked, :boolean, default: false
  attr :off, :boolean, default: false, doc: "dimmed: the photo can't be picked"
  attr :rest, :global, doc: "attributes for the checkbox"
  slot :inner_block, doc: "the note under the photo"

  def photo_tile(%{name: name} = assigns) when is_binary(name) do
    ~H"""
    <li class={["oc-photo-tile", @off && "oc-photo-tile-off"]}>
      <label>
        <span class="oc-photo-tile-image">
          <img :if={@src} src={@src} alt="" loading="lazy" />
          <input
            type="checkbox"
            name={@name}
            value={@value}
            checked={@checked}
            aria-label={@label}
            {@rest}
          />
        </span>
        <span :if={@inner_block != []} class="oc-photo-tile-note">{render_slot(@inner_block)}</span>
      </label>
    </li>
    """
  end

  def photo_tile(assigns) do
    ~H"""
    <li class={["oc-photo-tile", @off && "oc-photo-tile-off"]}>
      <span class="oc-photo-tile-image">
        <img :if={@src} src={@src} alt={@label} loading="lazy" />
        <span :if={!@src} class="sr-only">{@label}</span>
      </span>
      <div :if={@inner_block != []} class="oc-photo-tile-note">{render_slot(@inner_block)}</div>
    </li>
    """
  end

  @photo_statuses %{
    "added" => {"agree", "Added"},
    "exists" => {"agree", "Already added"},
    "adding" => {"open", "Adding…"},
    "failed" => {"differs", "Failed"}
  }

  @doc """
  Renders where a photo's import stands, as a `standing_mark/1` and its
  word: `added` (Added), `exists` (Already added), `adding` (Adding…) or
  `failed` (Failed). `error` says what went wrong, on its own line; the
  `:action` slot holds its one button (Retry).

  ## Examples

      <.photo_status status="adding" />

      <.photo_status status="failed" error="iNaturalist no longer has this photo (HTTP 404).">
        <:action><.button size="compact" phx-click="retry">Retry</.button></:action>
      </.photo_status>
  """
  attr :status, :string, required: true, values: Map.keys(@photo_statuses)
  attr :error, :string, default: nil
  slot :action, doc: "one button, such as Retry"

  def photo_status(assigns) do
    {standing, word} = Map.fetch!(@photo_statuses, assigns.status)
    assigns = assign(assigns, standing: standing, word: word)

    ~H"""
    <span class="oc-photo-status">
      <.standing_mark standing={@standing}>{@word}</.standing_mark>
      <span :if={@error} class="oc-photo-status-error">{@error}</span>
      <span :for={action <- @action} class="oc-photo-status-action">{render_slot(action)}</span>
    </span>
    """
  end

  @doc """
  Renders a photo's credit: its creator and its license, as a dialog lists
  it. A `reserved` photo (All Rights Reserved, used with the creator's
  permission) is marked © and its license set in bold.

  ## Examples

      <.photo_credit creator="janedoe - Jane Doe" license="CC-BY-NC" />
      <.photo_credit creator="janedoe" license="All rights reserved, used with the creator's permission" reserved />
  """
  attr :creator, :string, default: nil
  attr :license, :string, default: nil
  attr :reserved, :boolean, default: false

  def photo_credit(assigns) do
    ~H"""
    <span class="oc-photo-credit">
      <span :if={@creator}>{if @reserved, do: "© "}{@creator}</span>
      <strong :if={@license && @reserved}>{@license}</strong>
      <span :if={@license && !@reserved}>{@license}</span>
    </span>
    """
  end

  @doc """
  Renders a notice set between two 2px ink rules: a consequence inside a
  dialog that the editor must read, and confirm with the `:confirm` slot's
  checkbox, before the dialog's action is enabled (a photo whose creator
  keeps every right).

  ## Examples

      <.ruled_notice id="permission-notice">
        <p><strong>Photo 4 is All rights reserved.</strong> Its creator keeps every right to it.</p>
        <:confirm>
          <.input type="checkbox" name="permission" label="The creator has given permission to use this photo." />
        </:confirm>
      </.ruled_notice>
  """
  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true
  slot :confirm, doc: "the checkbox the editor ticks to confirm"

  def ruled_notice(assigns) do
    ~H"""
    <div id={@id} class={["oc-ruled-notice", @class]} {@rest}>
      {render_slot(@inner_block)}
      <div :for={confirm <- @confirm} class="oc-ruled-notice-confirm">{render_slot(confirm)}</div>
    </div>
    """
  end

  @doc """
  Renders a list of photos an editor puts in order, each a `photo_row/1`:
  the Manage photos dialog. Dragging a row's handle, or pressing Up or Down
  on it, moves the row, and the list sends `on_reorder` with
  `%{"order" => ids}` (each row's `photo_id`, as strings, in their new
  order) to the LiveView or LiveComponent it is rendered in (`target`) by
  the SortablePhotos hook in assets/js/app.js. The server's next render
  settles the order.

  ## Examples

      <.photo_list id="manage-photos" on_reorder="reorder_photos">
        <.photo_row :for={image <- @images} id={"photo-\#{image.id}"} photo_id={image.id} ...>
          ...
        </.photo_row>
      </.photo_list>
  """
  attr :id, :string, required: true
  attr :on_reorder, :string, required: true, doc: "the event sent with the new order"
  attr :target, :any, default: nil, doc: "the LiveComponent it is rendered in (`@myself`)"
  slot :inner_block, required: true

  def photo_list(assigns) do
    ~H"""
    <ul
      id={@id}
      class="oc-photo-list"
      phx-hook="SortablePhotos"
      phx-target={@target}
      data-event={@on_reorder}
    >
      {render_slot(@inner_block)}
    </ul>
    """
  end

  @doc """
  Renders one photo of a `photo_list/1`: its drag handle, a square
  thumbnail, its caption field (the inner block) and, under that, its meta
  line (`:meta`: a `photo_credit/1` or a `photo_status/1`) ending in its
  Delete button, which runs `on_delete`. A `muted` row (an import still
  adding or failed) dims its thumbnail.

  ## Examples

      <.photo_row
        id="photo-12"
        photo_id={12}
        src={Image.url(image, :small)}
        label="Photo 1"
        on_delete={JS.push("request_delete_photo", value: %{id: 12})}
      >
        <form phx-change="save_caption">...</form>
        <:meta><.photo_credit creator="janedoe" license="CC-BY-NC" /></:meta>
      </.photo_row>
  """
  attr :id, :string, required: true
  attr :photo_id, :any, required: true
  attr :label, :string, required: true, doc: "names the photo, as in \"Photo 2\""
  attr :src, :string, default: nil, doc: "the thumbnail's URL; none draws an empty tile"
  attr :muted, :boolean, default: false
  attr :on_delete, :any, required: true, doc: "the Delete button's phx-click"
  slot :inner_block, doc: "the caption field"
  slot :meta, doc: "the credit, or the import's status"

  def photo_row(assigns) do
    ~H"""
    <li id={@id} data-photo-id={@photo_id} class={["oc-photo-row", @muted && "oc-photo-row-muted"]}>
      <button
        type="button"
        class="oc-photo-row-grip"
        data-grip
        draggable="true"
        aria-label={"Move #{@label}: Up and Down arrow keys"}
        title="Drag to reorder"
      />
      <span class="oc-photo-row-thumb">
        <img :if={@src} src={@src} alt={@label} loading="lazy" />
      </span>
      <div class="oc-photo-row-body">
        {render_slot(@inner_block)}
        <div class="oc-photo-row-meta">
          {render_slot(@meta)}
          <button
            type="button"
            class="oc-photo-row-delete"
            phx-click={@on_delete}
            aria-label={"Delete #{@label}"}
          >
            Delete
          </button>
        </div>
      </div>
    </li>
    """
  end
end
