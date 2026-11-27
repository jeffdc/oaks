defmodule OaksWeb.Conformance do
  @moduledoc """
  Page code that builds its own version of something the component library
  covers (docs/COMPONENTS.md), as a ratchet held to
  `test/support/conformance_baseline.json` by `Oaks.GuardrailsTest`.

  Scans every .ex and .heex file under lib/oaks_web, line by line. Elixir `#`
  comment lines and one-line HEEx comments are skipped. Rules:

    * `width`: a page-width wrapper outside lib/oaks_web/components/ (widths
      belong to the page component and the layout): a line whose class
      tokens include both a max-w-* and mx-auto, or any page-scale width
      token on its own: max-w-3xl to max-w-7xl, max-w-screen-*, max-w-prose,
      max-w-frame. Tailwind variants (md:max-w-3xl) count. Not matched:
      dialog and element widths (max-w-md, max-w-lg, ...) and text measures
      (max-w-[68ch]) unless paired with mx-auto, and widths set in CSS.
    * `style`: an inline style attribute (style="..." or style={...})
      anywhere under lib/oaks_web, components included. Not matched: style=
      inside an Elixir string (style=\\"...\\"), as in help text.
    * `daisyui`: a daisyUI card or badge class anywhere under lib/oaks_web:
      the class token card or badge, or a card-*/badge-* modifier, inside a
      class= value on the line, or as the first word of a string literal
      made only of class tokens ("badge badge-muted"). Not matched: page
      classes that merely contain the word (taxon-card,
      comparison-preferred-badge), attributes named badge, and prose.
    * `sci_name`: hand-rolled scientific-name markup outside
      lib/oaks_web/components/ (where `<.sci_name>` lives) and the shared
      text helpers in lib/oaks_web/species_name.ex. One per line that opens
      an `<i>` or `<em>` element whose content, up to its closing tag (even
      lines later), names a taxon (`names_taxon?/1`); has the italic class
      token (not not-italic) and names a taxon on that line; defines a name
      helper (one count per clause: sci, sci_*, *_sci_name, *binomial*,
      epithet, formula_parts, name_iodata, name_html, name_parts,
      taxon_name, taxon_display_name, band_name, format_species_name); or
      builds the abbreviated genus in a string ("Q. \#{...}"). Not matched:
      plain-text names (page titles, URLs, "Quercus \#{x}" passed to a
      component), italics that don't name a taxon, and names in CSS.
    * `app_css`: assets/css/app.css's line count, which only shrinks.

  The rules came from `scripts/check-ui`, which this replaced. A new or raised
  baseline entry needs Jeff's approval.
  """
  use Heartwood.Guardrails.Patterns

  @web "lib/oaks_web/**/*.{ex,heex}"
  @components "lib/oaks_web/components/**/*.{ex,heex}"

  # Each line once, from its first non-blank character; the filter decides.
  @line ~r/\S.*/

  @impl Heartwood.Guardrails.Ratchet
  def subject, do: "off-library page code"

  @impl Heartwood.Guardrails.Ratchet
  def baseline_path, do: "test/support/conformance_baseline.json"

  @impl Heartwood.Guardrails.Patterns
  def intro,
    do:
      "New page code builds its own version of something the component library covers " <>
        "(docs/COMPONENTS.md)."

  @impl Heartwood.Guardrails.Patterns
  def outro,
    do:
      "Use the library's component, or add the missing one to the library first. " <>
        "A baseline entry for an exception needs Jeff's approval."

  @impl Heartwood.Guardrails.Patterns
  def rules do
    components = Path.wildcard(@components)

    [
      [
        name: :width,
        files: [@web],
        exempt: components,
        pattern: @line,
        filter: &(not comment?(&1) and page_width?(&1)),
        hint: "Set the page's width with <.page> (CoreComponents)."
      ],
      [
        name: :style,
        files: [@web],
        pattern: @line,
        filter: &(not comment?(&1) and &1 =~ ~r/(^|\s)style=["{]/),
        hint: "Use a component, or a class in assets/css/system; no inline styles."
      ],
      [
        name: :daisyui,
        files: [@web],
        pattern: @line,
        filter: &(not comment?(&1) and daisyui?(&1)),
        hint:
          "Use the library's components (a ruled row, a stamp or a mark), not daisyUI cards or badges."
      ],
      [
        name: :sci_name,
        files: [@web],
        exempt: ["lib/oaks_web/species_name.ex" | components],
        count: &length(sci_name_lines(&1)),
        hint:
          "Set scientific names with <.sci_name> (DesignComponents): no <i>/<em> or italic class " <>
            ~S|around a name, no name helpers of the page's own, no "Q. #{...}". | <>
            "OaksWeb.Conformance.sci_name_lines/1 lists the lines."
      ],
      [
        name: :app_css,
        files: ["assets/css/app.css"],
        count: &length(:binary.matches(&1, "\n")),
        hint: "Put styles in the components and assets/css/system, not app.css."
      ]
    ]
  end

  @doc "The lines (1-based) of `text` that hand-roll a scientific name."
  @spec sci_name_lines(String.t()) :: [pos_integer()]
  def sci_name_lines(text) do
    lines = text |> String.split("\n") |> List.to_tuple()

    for i <- 1..tuple_size(lines)//1,
        line = elem(lines, i - 1),
        not comment?(line),
        hand_rolled_name?(line) or names_taxon_in_element?(lines, i),
        do: i
  end

  @doc """
  Whether markup or code names a taxon: a scientific name field, Quercus or
  "Q. ", a taxon's name or rank field, or a call to a name helper.
  """
  @spec names_taxon?(String.t()) :: boolean()
  def names_taxon?(text) do
    text =~ ~r/scientific_name|Quercus|Q\.\s|taxon\.name|<\.taxon_name/ or
      text =~ ~r/\.(subgenus|section|subsection)([^a-z_]|$)/ or
      text =~
        ~r/(^|[^a-z_])(epithet|band_name|display_name|taxon_display_name|full_name|sci_html|name_iodata)\(/
  end

  defp comment?(line) do
    trimmed = String.trim(line)
    String.starts_with?(trimmed, "#") or trimmed =~ ~r/^<%!--.*--%>$/
  end

  defp page_width?(line) do
    (line =~ ~r/(?<![\w-])max-w-[^\s"]+(?![\w-])/ and line =~ ~r/(?<![\w-])mx-auto(?![\w-])/) or
      line =~ ~r/(?<![\w-])max-w-([3-7]xl|screen-[a-z0-9]+|prose|frame)(?![\w-])/
  end

  # A card or badge token in a class= value, or a string literal of class
  # tokens that starts with one ("badge badge-muted").
  defp daisyui?(line) do
    in_class_value? =
      ~r/class=(?:"([^"]*)|\{([^}]*))/
      |> Regex.scan(line, capture: :all_but_first)
      |> List.flatten()
      |> Enum.any?(&(&1 =~ ~r/(?<![\w-])(card|badge)(-[a-z0-9-]+)?(?![\w-])/))

    in_class_value? or
      line =~ ~r/"(card|badge)(-[a-z0-9-]+)?(\s+[\]A-Za-z0-9:_\/.\[-]+)*\s*"/
  end

  defp hand_rolled_name?(line) do
    line =~
      ~r/^\s*defp?\s+(sci|sci_[a-z0-9_]+|[a-z0-9_]+_sci_name|[a-z0-9_]*binomial[a-z0-9_]*|epithet|formula_parts|name_iodata|name_html|name_parts|taxon_name|taxon_display_name|band_name|format_species_name)[?!]?([\s(,]|$)/ or
      line =~ ~r/"Q\.\s#\{/ or
      (line =~ ~r/(?<![\w-])italic(?![\w-])/ and names_taxon?(line))
  end

  # An <i> or <em> opened on line i whose content, up to its closing tag
  # (read up to 20 lines on, or all 20 when it doesn't close), names a taxon.
  defp names_taxon_in_element?(lines, i) do
    line = elem(lines, i - 1)
    following = for k <- i..min(i + 18, tuple_size(lines) - 1)//1, do: elem(lines, k)

    ~r/<(i|em)[\s>]/
    |> Regex.scan(line, return: :index)
    |> Enum.any?(fn [{start, len}, tag] ->
      opened = binary_part(line, start + len - 1, byte_size(line) - start - len + 1)
      text = Enum.join([opened | following], "\n")

      case :binary.match(text, "</#{binary_part(line, elem(tag, 0), elem(tag, 1))}>") do
        {close, _} -> names_taxon?(binary_part(text, 0, close))
        :nomatch -> names_taxon?(text)
      end
    end)
  end
end
