---
name: Oak Compendium
description: A field reference for telling oaks and their hybrids apart, in one identifier's own words.
colors:
  ink: "#161616"
  ink-2: "#3d3d3a"
  ink-3: "#5c5c57"
  paper: "#fbfbf7"
  paper-2: "#f1f0e8"
  ochre: "#d9a21b"
  pencil: "#2f5fb3"
  rule: "#16161626"
  rule-strong: "#161616"
  iucn-ew: "#542344"
  iucn-cr: "#d81e05"
  iucn-en: "#fc7f3f"
  iucn-vu: "#f9e814"
  iucn-nt: "#cce226"
  iucn-lc: "#60c659"
  iucn-dd: "#d1d1c6"
typography:
  display:
    fontFamily: "Source Serif 4, Georgia, Times New Roman, serif"
    fontSize: "clamp(34px, 4vw, 50px)"
    fontWeight: 600
    lineHeight: 1.05
    letterSpacing: "-0.01em"
  headline:
    fontFamily: "Source Serif 4, Georgia, Times New Roman, serif"
    fontSize: "26px"
    fontWeight: 600
    lineHeight: 1.1
  title:
    fontFamily: "Source Serif 4, Georgia, Times New Roman, serif"
    fontSize: "18px"
    fontWeight: 600
    lineHeight: 1.25
  body:
    fontFamily: "Source Serif 4, Georgia, Times New Roman, serif"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.6
    fontFeature: "\"onum\" 1, \"pnum\" 1"
  quote:
    fontFamily: "Source Serif 4, Georgia, Times New Roman, serif"
    fontSize: "18px"
    fontWeight: 400
    lineHeight: 1.6
  frame:
    fontFamily: "Archivo, Helvetica Neue, Arial, sans-serif"
    fontSize: "15px"
    fontWeight: 700
    lineHeight: 1.45
  section-label:
    fontFamily: "Archivo, Helvetica Neue, Arial, sans-serif"
    fontSize: "15px"
    fontWeight: 800
    lineHeight: 1.2
    letterSpacing: "0.06em"
  breadcrumb:
    fontFamily: "Archivo Narrow, Archivo, Helvetica Neue, Arial, sans-serif"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: 1.4
    letterSpacing: "0.01em"
  source-mark:
    fontFamily: "Archivo, Helvetica Neue, Arial, sans-serif"
    fontSize: "12.5px"
    fontWeight: 500
    lineHeight: 1.3
  figures:
    fontFamily: "Archivo, Helvetica Neue, Arial, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.5
    fontFeature: "\"lnum\" 1, \"tnum\" 1"
rounded:
  none: "0px"
spacing:
  s1: "4px"
  s2: "8px"
  s3: "12px"
  s4: "16px"
  s5: "24px"
  s6: "32px"
  s7: "48px"
  s8: "64px"
components:
  masthead:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    height: "60px"
  taxonomy-band:
    backgroundColor: "{colors.ochre}"
    textColor: "{colors.ink}"
    typography: "{typography.breadcrumb}"
    height: "48px"
    padding: "0 32px"
  button-compare:
    backgroundColor: "{colors.ochre}"
    textColor: "{colors.ink}"
    rounded: "{rounded.none}"
    padding: "7px 10px"
  button-compare-hover:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.ochre}"
  status-tag:
    textColor: "{colors.ink}"
    rounded: "{rounded.none}"
    padding: "4px 7px"
  source-mark:
    textColor: "{colors.pencil}"
    typography: "{typography.source-mark}"
  section-heading:
    textColor: "{colors.ink}"
    typography: "{typography.section-label}"
    padding: "0 0 8px"
  search-field:
    textColor: "{colors.paper}"
    rounded: "{rounded.none}"
    padding: "11px 14px"
---

# Design System: Oak Compendium

## Overview

**Creative North Star: "The Twig Key, Unbound"**

The world takes a pocket dendrology key's printed materials and leaves its structure behind. Ink black on bright white stock, one committed ochre field, a pencil blue for the marks that lead to sources, a heavy grotesk for the frame and a sturdy text serif for reading. The pages are dense in the way a good field guide is dense: statements stand on rules, never in boxes, and the eye moves down ruled lists and aligned columns rather than across stacked cards.

The page answers "is it this, or that?" before anything else. Where the taxon sits is shown in the same ochre band on every taxon page; the traits that set it apart come first; look-alikes and hybrids sit one step away; a side-by-side comparison aligns two taxa trait by trait. Jeff's words are always quoted and always carry a source mark. What the system derives from his words is set in the frame face, so a reader never mistakes a summary for his voice. Other sources sit behind his, as they wrote it.

The key's printed materials are kept; its apparatus is not. There are no couplets, no key numbering, no dotted leaders, no key path and no life-size callouts.

**Key Characteristics:**
- Ink on bright stock, one ochre field, pencil-blue source marks.
- Archivo frames and labels; Source Serif 4 carries reading text and every scientific name.
- Square corners everywhere; rules, not boxes, separate statements.
- Agree, differs and unreviewed are drawn marks, never colours. IUCN status alone keeps its Red List colours.
- Taxonomy breadcrumb in the ochre band, in the same place on every taxon page.
- Counts and measurements in lining tabular figures; running text in oldstyle figures.

## Colors

A near-monochrome printed palette with one saturated field and one working blue.

### Primary
- **Ochre Band** (ochre): the one committed field. It fills the taxonomy band, the Compare buttons, the current-item underline in the masthead nav and the comparison switcher, the 3px underline that marks a trait row where two taxa differ, and text selection. It is a fill and an underline, never a text colour on paper.

### Secondary
- **Pencil Blue** (pencil): links and source marks. Every source mark is pencil blue with a thin underline at 40% (#2f5fb366), full strength on hover. Also the focus outline colour.

### Neutral
- **Press Ink** (ink): body text, the masthead ground, the strong 2px rules under titles and section headings, the outlined status tag, the EX status fill.
- **Second Ink** (ink-2): quoted and secondary reading text, captions, the standing marks' labels.
- **Third Ink** (ink-3): authority, quiet metadata, empty states ("No statement yet"), source attributions under other sources' text.
- **Bright Stock** (paper): the page ground and the text colour on the ink masthead.
- **Second Stock** (paper-2): photo placeholders, carousel thumbnails, the hybrid's middle column in a three-way comparison, the prototype banner.
- **Hairline** (rule): the 1px rule between list rows, table rows and trait statements.
- **Strong Rule** (rule-strong): 2px rules under the title row, section headings and table heads.

### Named Rules
**The One Field Rule.** Ochre is the only saturated fill in the world. It marks where you are (band, current nav item, current comparison), what to do next (Compare) and where two taxa differ. Nothing else gets a coloured ground, except the IUCN status stamp (The IUCN Exception, below).

**The Marks Not Colours Rule.** Agree, differs and unreviewed are drawn marks in ink: a ticked open circle for agree, a filled square carrying a paper not-equal sign (two bars struck through) for differs, a dashed open circle for unreviewed or not recorded. Never encode standing with green, red or amber.

### The IUCN Exception
IUCN Red List status is the one categorical colour code allowed outside the One Field and Marks Not Colours rules. The Red List's category colours are a convention identifiers and botanists already read at a glance, and the colourless stamp made the codes too hard to tell apart (Jeff, 2026-11-21, decision 5604). The status tag takes the category's fill, keeps its 1.5px ink outline and square corners, and always shows the code with the colour, never colour alone; the category is spelled out in its title and for screen readers. Every page uses one component, `iucn_status`. The fills are the Red List's own, except EX (ink instead of pure black) and NE (paper, the plain stamp):

| Code | Category | Fill | Code text | Contrast |
|------|----------|------|-----------|----------|
| EX | Extinct | ink #161616 | paper | 17.4:1 |
| EW | Extinct in the Wild | #542344 | paper | 11.9:1 |
| CR | Critically Endangered | #d81e05 | paper | 4.9:1 |
| EN | Endangered | #fc7f3f | ink | 7.1:1 |
| VU | Vulnerable | #f9e814 | ink | 14.3:1 |
| NT | Near Threatened | #cce226 | ink | 12.5:1 |
| LC | Least Concern | #60c659 | ink | 8.4:1 |
| DD | Data Deficient | #d1d1c6 | ink | 11.8:1 |
| NE | Not Evaluated | paper #fbfbf7 | ink | 17.4:1 |

The colours mean the Red List category and nothing else: they never mark standing, differences, sources or any other status.

## Typography

**Display Font:** Source Serif 4 (with Georgia, Times New Roman)
**Body Font:** Source Serif 4 (with Georgia, Times New Roman)
**Frame Font:** Archivo (with Helvetica Neue, Arial); Archivo Narrow for the taxonomy band only

**Character:** A heavy, plain grotesk builds the frame (headings, labels, trait names, derived values, buttons, source marks) while a sturdy text serif carries everything meant to be read, and every scientific name. The contrast between the two faces is how the page separates Jeff's voice from the apparatus around it.

### Hierarchy
- **Display** (Source Serif 4 600, clamp(34px, 4vw, 50px), 1.05): every page title (Components, Title Row), roman; a taxon name there is italic, genus at weight 400, epithet at 600. Followed by the authority in 22px roman serif at ink-3 and the common name in 21px Archivo 700.
- **Headline** (Source Serif 4 italic 600, 26px to 28px, 1.1): taxon names heading comparison columns and the parents strip on hybrid pages.
- **Title** (Source Serif 4 italic 600, 18px, 1.25): a taxon name that is itself a list entry: the species list, search results, look-alikes, hybrids, relatives and a taxon's species, all at 18px (the authority 15px).
- **Body** (Source Serif 4 400, 17px, 1.6; 16px under 760px): running text with oldstyle proportional figures. Prose pages hold it to the 720px reading measure; reading text inside a wider page holds at 68ch to 70ch.
- **Quote** (Source Serif 4 400, 18px, 1.6, ink): Jeff's statements in the distinguishing-traits list; 16px in tables and comparisons.
- **Frame** (Archivo 700, 15px, 1.45): trait names and derived values; Archivo 400 to 600 at 13px to 14px for "why" notes, captions and metadata.
- **Section label** (Archivo 800, 15px, 0.06em, uppercase): section headings standing on a 2px ink rule, with an optional right-aligned 13px Archivo 500 note at ink-3. Table heads and range country headings use the same voice at 13px.
- **Breadcrumb** (Archivo Narrow 600, 15px, 0.01em): the taxonomy band; rank words at weight 500, names in Source Serif 4 italic at 16px, the current taxon's epithets at 700.
- **Source mark** (Archivo 500, 12.5px): source links after a quote or value.

### Named Rules
**The Verbatim Rule.** Jeff's words always appear in quotation marks (curly quotes) and are always followed by a source mark. Anything derived from his words, a summary value, a count, a label, is set in the frame face with a small Archivo tag ("summary", "from counts") and never in quotation marks.

**The Botanical Italic Rule.** Scientific names are italic per botanical convention, in the serif, everywhere: titles, lists, breadcrumbs, tables, prose. Rank words (subg., sect., subsect., complex), authorities and the hybrid sign stay roman, the sign spaced and held to its neighbours (*Quercus* × *bebbiana*). The genus is set at 400 and the epithets at 600, or all at 400 in running text; the authority follows in roman ink-3. Every name is one component, `sci_name`, so the same name looks the same everywhere at a given size.

- **Size follows the name's role:** display in the title row (the authority at 22px), headline (26px) heading a comparison column, title (18px) for a name that is itself a list entry (the species list, search results, a taxon's species, a species' hybrids and relatives, a source's species), 14px at 400 in an Archivo metadata line beside a list entry (its rank word in the frame face, as in the band: sect. *Lobatae*), and otherwise the size of the text around it (prose, dialogs, table cells, field values). The taxonomy band keeps its own voice: names at 16px, the current taxon's epithets at 700.
- **Quercus, Q. or no genus:** *Quercus* in full in the title row, at a name's first mention in a dialog or passage, and in lists whose entries each stand alone; *Q.* after that, in lists under a taxon or record already named (parents, hybrids, relatives, varieties, a source's species), in comparison column heads, for the current species in the band, for a complex, which is named for its species (*Q. coccinea* complex), and for a species' synonyms (*Q. candida* Steud.; a synonym in another genus keeps it in full, *Cyclobalanopsis glauca* (Thunb.) Oerst., since only *Quercus* is ever abbreviated); no genus for names above species (subgenus, section, subsection) and for a hybrid's other parent after "with" (*Q.* × *bebbiana* with *macrocarpa*).

**The Two Figures Rule.** Running text uses oldstyle figures; counts, measurements and table cells use lining tabular figures.

## Layout

The masthead and footer run a 1400px maximum frame with 32px side gutters (16px under 760px); a page's content takes the centred 960px column unless it sets columns side by side (see the named widths below). Every taxon page stacks the same way: ink masthead (60px minimum), ochre taxonomy band, title row on a 2px rule, then content. The band runs the window's full width straight under the masthead (the page's bleed), its path set in the masthead's 1400px frame, so it stands in the same place on every taxon page whatever the page's width; the title row follows in the page's head, as on every other page.

The primary taxon page (the target design; today's single-column species and taxonomy pages take the column until it ships, and then it takes the frame) uses three columns at desktop: photos 300px left (sticky), the distinguishing traits as the reading column centre, look-alikes and hybrids in a 330px right rail, 48px apart. Under 1180px the rail drops below as two side-by-side lists. Under 760px everything is one column ordered traits, rail, photos; the field-marks table becomes one block per trait with each source labelled; the band scrolls horizontally, pinned to the current taxon with a fade on the left edge.

Wide sections below (field marks, range, notes and names, sources) run the full frame, 64px apart. Range is text first with the map's place reserved beside it. Comparisons are an aligned grid: a 140px trait column then one column per taxon (three for a hybrid between its parents), collapsing to labelled stacks on phones.

Spacing is an 8-step scale from 4px to 64px (s1 to s8); 16px and 24px carry most internal rhythm, 48px separates sections within a column.

Every page takes one of four named widths (`<.page>`), chosen by what the page is: the **column** (960px, centred) for every single-column page, so lists, taxon pages, search, a record such as a source, the articles list and analytics; the **reading measure** (720px, centred) for prose, so articles, about, privacy and help; the **form measure** (760px, centred) for forms that create or edit, and the account pages (log in, setup, settings); the **frame** (1400px) only for pages that set columns side by side, so the source comparison and a merge. The home page is set centred in the frame, as a book's title page and contents: its title page in the full-width bleed above its frame, its contents and colophon centred in the frame. The error pages (403, 404, 500) take the reading measure, in the site's own masthead and footer.

### Named Rules
**The Centred Column Rule.** A single-column page sits in one centred 960px column, and its title row and 2px rule run the column's width, not the window's (decision a0ac). Prose and forms sit in a narrower centred column at their reading (720px) or form (760px) measure, the title row and its rule at that measure too, so the title and the text under it share one centred edge (Jeff, 2026-11-22, item a44d); a row's name and its details never sit 1300px apart on a wide screen. The 1400px frame is only for pages whose content stands in columns side by side.

**The One Template Rule.** Every taxon page uses the same template. A section appears because its data exists, never because Jeff has or hasn't covered the taxon: the source comparison appears whenever there are two or more sources (never with only one), and look-alikes, hybrids and range appear when their data exists. A taxon Jeff hasn't covered gets the same full page plus the not-covered notice, never a poorer stub layout.

## Elevation & Depth

Entirely flat. There are no shadows anywhere. Depth is conveyed by rules (1px hairlines between rows, 2px ink rules under headings), by the two inks of the ground (paper and paper-2), and by the two solid fields, the ink masthead and the ochre band.

### Named Rules
**The Statements On Rules Rule.** Statements stand on rules, never in boxes. No cards, no shadows, no tinted panels around content. The only bordered shapes are small: the Compare button, the status tag, photo frames and the dashed map slot.

## Shapes

Square corners throughout (0px); the focus outline alone carries a 1px corner. Borders are hairline (1px at 15% ink), strong (2px ink) or outlined (1.5px ink on buttons and the status tag). Chevrons in the breadcrumb and the disclosure toggle are drawn from two borders rotated 45 degrees, not glyphs. The comparison's differing rows are underlined with a 3px ochre bar along the bottom edge. The reserved map place is a 1.5px dashed rectangle at 40% ink.

## Components

### Buttons
Plain, printed, square.
- **Shape:** square corners (0px), 1.5px ink outline.
- **Compare (primary):** ochre fill, ink text, Archivo 700 13px, 7px by 10px padding. Hover inverts to ink fill with ochre text.
- **Focus:** 3px pencil-blue outline, 2px offset, on every interactive element.

### Title Row
Every page's title is one component, `header`, on one rule (item 7838): the title in the display serif (clamp(34px, 4vw, 50px), 600, balanced) standing on a 2px ink rule, 16px of space above the rule and 32px below it. The row uses the page's width; editing never shapes it.
- **Title line:** the title, then the meta on the same line, 24px after the title (and a species' authority), on its baseline. The meta wraps under the title, 12px below it, only when the line has no room for it (long titles, phones).
- **Meta:** Archivo 600 14px ink-2 with lining tabular figures, items 16px apart with no separators. It holds what kind of thing the page is and its short facts, in this order: the kind word (Species, Hybrid, Subgenus) or the record a form edits (its name at 14px), counts (497 species), a byline and date, stamps (the status tag, the IUCN status, a dashed Draft), then links such as an article's tags.
- **Subtitle:** a sentence describing the page, Archivo 600 16px ink-2 at most 70ch, under the title line.
- **Edit menu:** an editor's actions for the page (Edit, Make synonym of…, Delete, Create taxon, New species…) sit in one small disclosure, `edit_menu`: a compact "Edit" button with a drawn chevron at the right end of the row, on the title's first baseline, reversed to paper on ink while open. Its list opens under it on its right edge, on paper in a 1.5px ink border, Archivo 600 14px items on paper-2 when hovered; Esc, a click outside or choosing an item closes it, and a destructive item opens its confirmation dialog. It never wraps: the title and meta take the rest of the row. Logged out there is no menu and no space kept for one.
- **Back link:** above the row, 16px over the title, in the page's head with it.

### Status Tag
An outlined ink stamp: Archivo 700 13px at 0.04em, 1.5px ink border, 4px by 7px padding, followed by a source mark when it is sourced. The IUCN status variant (IUCN LC with its assessment on the taxon page, the bare code in the species list) fills the stamp with its Red List category colour (The IUCN Exception).

### Source Marks
Archivo 500 12.5px pencil blue, a 1px underline at 40% that firms up on hover, never wraps. Follows every quote and every sourced value. Other sources' text carries its attribution as an Archivo 600 13px ink-3 line beneath it.

### Standing Marks
A 14px drawn mark plus an Archivo 600 12.5px ink-2 label: agree (ticked open circle), differs (filled square carrying a paper not-equal sign), unreviewed or not recorded (dashed open circle). The ≠ means a conflict: sources disagree (taxon pages) or your tree conflicts with a taxon (ID tool); the comparison uses the key-difference star instead. Used beside trait statements, as disclosure summaries for other sources, in comparison row heads and as the comparison legend.

### Navigation
- **Masthead:** ink ground, acorn mark and "Oak Compendium" in Archivo 800 19px, nav in Archivo 600 15px paper. Current item takes a 3px ochre underline; hover a 3px underline at 40% paper.
- **Search:** square field on the masthead with a 1px paper border at 35%, a faint paper wash, paper text, and a "/" key hint that hides on phones.
- **Editor marks:** logged in, the nav's next item is Editor, a menu of the editor's tools on a paper panel with a 1.5px ink border, followed by the editor's name in Archivo 700 14px ochre. Until the authoring editor exists the menu holds Add species, Settings and Log out.
- **Narrow masthead:** at 1024px and under the masthead stacks: the mark (with the editor marks at the right), the search full width, then the nav on its own scrolling row along the bottom edge.
- **Site footer:** under a hairline, the licensing line in Archivo 500 13px ink-3 ("Oak Compendium’s prose is © all rights reserved", "All facts are free to use", "Other sources are under their own terms"), and at the right the pages with no main nav item in pencil: Articles, Privacy, API, and Log in when logged out.
- **Taxonomy band:** the ochre band with every rank linked (genus, subgenus, section, subsection, complex, taxon), separated by drawn chevrons, in the same place on every taxon page including hybrids, varieties and the comparison view. One crumb format everywhere: rank words (subg., sect., subsect.) roman before the name and "complex" after it; names in the serif italic at 16px, bare from genus to subsection, *Q.* for a complex and a species, the current taxon's epithets at 700. The path is one line at a fixed height (48px, 42px on phones) on every page and at every width, so the band never grows. A variety sits under its species (*Q. acutissima* › *Q. acutissima kingii*). A hybrid sits at its own stored ranks; one with none stored sits where both its parents do, down to the last rank they share (*Q.* × *alentejana* under sect. *Quercus*), and under the genus alone when its parents part at the subgenus. On the source comparison the species stays the current taxon. At its right end a siblings menu (Archivo Narrow 600 14px, 1.5px ink outline, label like "Coccineae · 7 species") opens a list of the other taxa at that rank, the current one on an ochre ground; open, the button reverses to ochre on ink. Long groups list a few and link to all. On phones the band is 42px tall and its path starts at the 16px gutter. At any width a path longer than the line scrolls, scrolled to the current taxon; while steps are scrolled off to the left it fades at its left edge, and with a mouse a thin ink scrollbar along its foot leads back to them.

### Ruled Lists
Look-alikes, hybrids, distinguishing traits and field marks are all rows on hairlines. A look-alike row holds the italic name, a one-line Archivo "why" note and a Compare button; a hybrid row holds the name and "with" its other parent. A distinguishing trait row is a 132px Archivo trait name beside the derived value, Jeff's quote with its source mark, and its standing mark.

### Field Marks Table
Trait, Jeff Clark, Other sources. Jeff's column is serif; empty cells read "No statement yet" in italic ink-3. Other sources sit behind a disclosure whose summary is a standing mark, opening to each source's text as they wrote it with its attribution.

### Comparison (signature)
Two taxa (or two parents around a hybrid) aligned trait by trait in columns, each row headed by a standing mark and trait name; rows where they differ carry the 3px ochre underline. A switcher row of italic taxon names picks the other taxon, the current one underlined in ochre. The second column slides in once (420ms, cubic-bezier(0.16, 1, 0.3, 1), a clip reveal with a 12px shift), and does not animate under reduced motion. The comparison is a mode of the taxon page, not a separate page: the URL gains ?vs=<taxon> (deep-linkable), the page keeps its masthead, band and title, the distinguishing-traits area becomes the side-by-side, the rest of the page continues below, and "Close comparison" returns to the plain page. In the comparison, a key difference is marked with a star (ochre fill, ink outline) and the legend reads "key difference".

### ID Tip
The comparison's closing row: one of Jeff's verbatim statements that settles the pair, spanning both taxon columns in serif 23px with its source mark. Its label is a reversed plate in the trait column: ochre Archivo 800 17px capitals on ink with a drawn magnifier, the same ink-and-ochre pairing as an open band menu. The row stands between a 2px ink rule above and a 5px ochre rule below. Label wording: "ID tip".

### Jeff's Write-up (fragment and reader)
The gallformers ID Notes pattern, and a candidate for a component shared with gallformers. Jeff's general write-up of the taxon sits directly under the title row, above the distinguishing traits: the most important content on the page, and it never dominates it. On the page: a row between a 2px ink rule and a hairline, a 132px label column ("Jeff's write-up" in Archivo 800 13px capitals, a meta line under it) beside a two-line fragment of the main description in Source Serif 17px ink-2, clamped with an ellipsis, then "Read ›" in Archivo 800 13px on a 3px ochre underline. The whole fragment is one button; it tints paper-2 on hover. It opens the reader: a centred modal dialog (880px, 88vh; full screen on phones) with the taxon name in serif italic, "Jeff Clark's description", a Close button with an Esc hint, a meta line with A−/A+ text-size buttons (16 to 23px), the main description only (no notes, no topic index) under ruled uppercase subheads at a 66ch measure, and a footer with "Copy link" and Close. Esc, a click outside and Close all close it; ?read=description opens it directly and the URL follows it. On phones the label stacks above the fragment.

### ID Tool Workbench
The Identify area (Trait filter, Hybrid helper, ID mode) is one Workbench: tabs in the ochre band (current tab reversed ink on ochre) with the place at the band's right; three panes under it. Left: "Your tree", place first, then traits by organ (leaves, acorns, buds, bark, habit), the pane sticky and self-scrolling on desktop. Middle: the result. Right: the selected taxon, the known hybrid, or the comment. Below 760px the panes stack. A separate phone view is planned, not built.

Trait controls: option buttons (1.5px outline; pressed is ink with a small ochre tick) where picking several means "any of these" (the hedge, explained once at the top of the pane); number pairs "from … to" for counts such as lobes or teeth per side.

Matching rules shown in the UI: an observed range is consistent with any taxon range it overlaps; nothing is ever removed or hidden; candidates sit in three open groups (Consistent with everything, One conflict, Two or more conflicts) with counts in tabular figures. Each row: thumbnail, italic name and common name (a HYBRID tag where it applies), a strip of per-trait marks (agree, ≠ conflict, dashed no data), and one line per conflict, led by ≠: "Trait: taxon value · you: your value". No data counts neither for nor against. A "Check next" line on rules names the trait that best separates the consistent group and links to its control. The selected row is outlined in ink.

Hybrid helper uses the comparison component: parent | their hybrids (tinted column) | parent, the user's value under each trait name, marks in the row heads, one block per trait on phones. ID mode puts the iNat observation (URL, photos, meta) at the top of the left pane and a comment builder on the right: the comment lists what the identifier ticked in their own hedged terms ("bristle or mucro tips (can't tell which)") plus the Compendium link, with Copy comment and an optional Save.

### Authoring Editor
Jeff only, behind login, desk-first. The masthead marks Editor and Jeff; the ochre band holds the taxon (serif italic), the Entry / Facts / Conflicts tabs (current reversed), a "This taxon / This section across taxa" switch, save state, Preview and "Publish written sections". Two columns: the work on the left, material or context on the right.

Entry: section blocks on 2px ink rules, one per section of the shared entry structure (Key sentence, Account, Historical context, more to come). Each block header has the section name, its stated purpose and a state: Draft (dashed outline), Review (ochre with the ≠ mark), Written (ink fill with the agree mark), Empty (dashed open mark). The focused block carries a 4px ochre top rule. Text fields are white with a 1.5px border (the one sanctioned box: an editable field needs a boundary) and an ink caret. The Key sentence block shows a check row (one sentence, length against the two-line fragment, a prompt to say what the oak is first) and a preview cut at the taxon page's real fragment. Each block footer: word count, provenance summary, Versions, and Mark written (dashed and disabled while agent wording remains).

Provenance marks inside the text: Jeff's inserted passages are tinted pencil-blue with a pencil source mark; a trimmed insert says "trimmed" (trimming adds no words). Agent wording (pre-existing text not in Jeff's words) is italic ink-2 with a light underline, sentence by sentence, until Jeff retypes it; a section can't be adopted wholesale.

Material column: tabs (Your material, Other sources, Set aside), a search field, passages as quotes in serif with a source mark, folded-duplicate counts, Set aside and an ochre Insert; passages already used say where ("in Account").

Facts and Conflicts are queues of rows on 2px rules: trait (and sub-trait) left; the proposed value and Jeff's exact supporting sentence (cut with "…") or the side-by-side values (Jeff's cell tinted paper-2) in the middle; actions stacked right (ochre primary). Decided rows show the verdict with who and date, and Undo. The row in focus carries the ochre top rule. Keyboard hints (kbd) sit on the actions.

### Hybrid Parents Strip
The hybrid's two parents left and right in headline italics with common name and a key trait below, the hybrid name between them set off by hairlines, all standing on a 2px rule.

### Not-Covered Notice
On any taxon Jeff hasn't covered, placed under the title row of the full template: a paragraph between two 2px ink rules in Archivo 500 16px, opening with a bold statement that the Compendium doesn't yet hold Jeff's own data on the taxon. It adds to the page; it never replaces sections with a reduced layout.

## Do's and Don'ts

### Do:
- **Do** put the taxonomy breadcrumb in the ochre band, in the same place on every taxon page, every rank linked.
- **Do** lead with the distinguishing traits, and keep look-alikes (each with Compare) and hybrids (each with its other parent) one step away.
- **Do** set Jeff's words in curly quotation marks followed by a pencil-blue source mark, every time.
- **Do** set derived values (summaries, counts) in Archivo, tagged with how they were derived, and never in quotation marks.
- **Do** show other sources behind Jeff's, as they wrote it, each with its attribution.
- **Do** use the same taxon template everywhere, showing a section whenever its data exists (the source comparison only with two or more sources).
- **Do** mark agree, differs and unreviewed with the drawn marks, labelled in words.
- **Do** italicize scientific names in the serif; keep ranks, authorities and the hybrid sign roman.
- **Do** separate statements with rules: 1px hairlines between rows, 2px ink under headings.
- **Do** set counts and measurements in lining tabular figures.

### Don't:
- **Don't** borrow the dichotomous key's structure: no couplets, key numbering, dotted leaders, key path or life-size callouts.
- **Don't** encode agree, differs or unreviewed with colour.
- **Don't** put statements in boxes, cards, tinted panels or shadows.
- **Don't** add a second saturated colour or use ochre as text on paper. The IUCN status fills are the one exception, and only for the Red List category.
- **Don't** round corners.
- **Don't** set anything that is not Jeff's verbatim wording in quotation marks or in a way that reads as his voice.
- **Don't** hide conflicts between sources behind tabs; mark them in place.
- **Don't** give a taxon Jeff hasn't covered a poorer stub layout; it gets the full page plus the not-covered notice.
