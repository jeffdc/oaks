package editor

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"

	"github.com/jeff/oaks/cli/internal/models"
	"github.com/jeff/oaks/cli/internal/schema"
	"gopkg.in/yaml.v3"
)

// parseFrontmatter extracts YAML frontmatter and body from markdown content
// Returns frontmatter (without ---), body, and any error
func parseFrontmatter(content string) (frontmatter string, body string, err error) {
	content = strings.TrimSpace(content)
	if !strings.HasPrefix(content, "---") {
		return "", content, nil
	}

	// Find the closing ---
	rest := content[3:] // skip opening ---
	rest = strings.TrimPrefix(rest, "\n")
	idx := strings.Index(rest, "\n---")
	if idx == -1 {
		return "", "", fmt.Errorf("unclosed frontmatter: missing closing ---")
	}

	frontmatter = rest[:idx]
	body = strings.TrimSpace(rest[idx+4:]) // skip \n--- and trim
	return frontmatter, body, nil
}

// extractSection extracts content under a markdown heading (e.g., "# Range")
// Returns the content between this heading and the next heading (or end of document)
func extractSection(body, heading string) string {
	// Match heading with optional whitespace
	pattern := `(?m)^#\s*` + regexp.QuoteMeta(heading) + `\s*$`
	re := regexp.MustCompile(pattern)
	loc := re.FindStringIndex(body)
	if loc == nil {
		return ""
	}

	// Find where content starts (after the heading line)
	start := loc[1]
	for start < len(body) && body[start] != '\n' {
		start++
	}
	if start < len(body) {
		start++ // skip the newline
	}

	// Find the next heading or end of document
	nextHeading := regexp.MustCompile(`(?m)^#\s+`)
	rest := body[start:]
	nextLoc := nextHeading.FindStringIndex(rest)
	if nextLoc == nil {
		return strings.TrimSpace(rest)
	}
	return strings.TrimSpace(rest[:nextLoc[0]])
}

// getEditor returns the user's preferred editor
func getEditor() string {
	if editor := os.Getenv("EDITOR"); editor != "" {
		return editor
	}
	return "vi"
}

// openEditorWithExt opens the editor with the given content and file extension
func openEditorWithExt(initialContent, ext string) (string, error) {
	editor := getEditor()

	tmpFile, err := os.CreateTemp("", "oak-*"+ext)
	if err != nil {
		return "", fmt.Errorf("failed to create temp file: %w", err)
	}
	tmpPath := tmpFile.Name()
	defer os.Remove(tmpPath)

	if _, err := tmpFile.WriteString(initialContent); err != nil {
		tmpFile.Close()
		return "", fmt.Errorf("failed to write temp file: %w", err)
	}
	tmpFile.Close()

	cmd := exec.Command(editor, tmpPath)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("editor '%s' exited with error: %w", editor, err)
	}

	content, err := os.ReadFile(tmpPath)
	if err != nil {
		return "", fmt.Errorf("failed to read edited content: %w", err)
	}

	return string(content), nil
}

// openEditor opens the editor with YAML content (.yaml extension)
func openEditor(initialContent string) (string, error) {
	return openEditorWithExt(initialContent, ".yaml")
}

// openEditorMarkdown opens the editor with markdown content (.md extension)
func openEditorMarkdown(initialContent string) (string, error) {
	return openEditorWithExt(initialContent, ".md")
}

// waitForEnter waits for the user to press Enter
func waitForEnter() {
	reader := bufio.NewReader(os.Stdin)
	reader.ReadString('\n')
}

// oakEntryToMarkdown generates a markdown string for editing an oak entry
func oakEntryToMarkdown(e *models.OakEntry) string {
	deref := func(p *string) string {
		if p == nil {
			return ""
		}
		return *p
	}

	formatArray := func(arr []string) string {
		if len(arr) == 0 {
			return "[]"
		}
		var sb strings.Builder
		sb.WriteString("\n")
		for _, v := range arr {
			sb.WriteString(fmt.Sprintf("  - %s\n", v))
		}
		return strings.TrimSuffix(sb.String(), "\n")
	}

	var fm strings.Builder
	fm.WriteString("---\n")
	fm.WriteString(fmt.Sprintf("scientific_name: %s\n", e.ScientificName))
	fm.WriteString(fmt.Sprintf("author: %s\n", deref(e.Author)))
	fm.WriteString(fmt.Sprintf("is_hybrid: %t\n", e.IsHybrid))
	fm.WriteString(fmt.Sprintf("conservation_status: %s\n", deref(e.ConservationStatus)))
	fm.WriteString("\n")
	fm.WriteString(fmt.Sprintf("subgenus: %s\n", deref(e.Subgenus)))
	fm.WriteString(fmt.Sprintf("section: %s\n", deref(e.Section)))
	fm.WriteString(fmt.Sprintf("subsection: %s\n", deref(e.Subsection)))
	fm.WriteString(fmt.Sprintf("complex: %s\n", deref(e.Complex)))
	fm.WriteString("\n")
	fm.WriteString(fmt.Sprintf("parent1: %s\n", deref(e.Parent1)))
	fm.WriteString(fmt.Sprintf("parent2: %s\n", deref(e.Parent2)))
	fm.WriteString("\n")
	fm.WriteString(fmt.Sprintf("hybrids: %s\n", formatArray(e.Hybrids)))
	fm.WriteString(fmt.Sprintf("closely_related_to: %s\n", formatArray(e.CloselyRelatedTo)))
	fm.WriteString(fmt.Sprintf("subspecies_varieties: %s\n", formatArray(e.SubspeciesVarieties)))
	fm.WriteString(fmt.Sprintf("synonyms: %s\n", formatArray(e.Synonyms)))
	fm.WriteString("---\n")

	return fm.String()
}

// parseOakEntryMarkdown parses markdown content back into an OakEntry
func parseOakEntryMarkdown(content string) (*models.OakEntry, error) {
	fm, _, err := parseFrontmatter(content)
	if err != nil {
		return nil, err
	}

	var entry models.OakEntry
	if err := yaml.Unmarshal([]byte(fm), &entry); err != nil {
		return nil, fmt.Errorf("failed to parse frontmatter: %w", err)
	}

	return &entry, nil
}

// EditOakEntry edits an Oak entry with validation loop
func EditOakEntry(entry *models.OakEntry, validator *schema.Validator) (*models.OakEntry, error) {
	content := oakEntryToMarkdown(entry)

	for {
		editedContent, err := openEditorMarkdown(content)
		if err != nil {
			return nil, err
		}

		editedEntry, err := parseOakEntryMarkdown(editedContent)
		if err != nil {
			fmt.Fprintf(os.Stderr, "\nFailed to parse markdown: %v\n", err)
			fmt.Fprintln(os.Stderr, "Press Enter to re-open the editor and fix the error...")
			waitForEnter()
			content = editedContent
			continue
		}

		if err := validator.ValidateOakEntry(editedEntry); err != nil {
			fmt.Fprintf(os.Stderr, "\nValidation failed:\n%v\n", err)
			fmt.Fprintln(os.Stderr, "\nPress Enter to re-open the editor and fix the errors...")
			waitForEnter()
			content = editedContent
			continue
		}

		return editedEntry, nil
	}
}

// NewOakEntry creates a new Oak entry with validation loop
func NewOakEntry(scientificName string, validator *schema.Validator) (*models.OakEntry, error) {
	template := models.NewOakEntry(scientificName)
	return EditOakEntry(template, validator)
}

// EditSource edits a Source entry
func EditSource(source *models.Source) (*models.Source, error) {
	content := sourceToMarkdown(source)
	originalID := source.ID

	for {
		editedContent, err := openEditorMarkdown(content)
		if err != nil {
			return nil, err
		}

		editedSource, err := parseSourceMarkdown(editedContent)
		if err != nil {
			fmt.Fprintf(os.Stderr, "\nFailed to parse markdown: %v\n", err)
			fmt.Fprintln(os.Stderr, "Press Enter to re-open the editor and fix the error...")
			waitForEnter()
			content = editedContent
			continue
		}

		// Reject ID changes
		if editedSource.ID != originalID {
			fmt.Fprintf(os.Stderr, "\nID cannot be changed (was %d, attempted %d)\n", originalID, editedSource.ID)
			fmt.Fprintln(os.Stderr, "Press Enter to re-open the editor and fix the error...")
			waitForEnter()
			content = editedContent
			continue
		}

		if editedSource.Name == "" {
			fmt.Fprintln(os.Stderr, "\nname cannot be empty")
			fmt.Fprintln(os.Stderr, "Press Enter to re-open the editor and fix the error...")
			waitForEnter()
			content = editedContent
			continue
		}

		if editedSource.SourceType == "" {
			fmt.Fprintln(os.Stderr, "\nsource_type cannot be empty")
			fmt.Fprintln(os.Stderr, "Press Enter to re-open the editor and fix the error...")
			waitForEnter()
			content = editedContent
			continue
		}

		return editedSource, nil
	}
}

// sourceToMarkdown generates a markdown string for editing a source
func sourceToMarkdown(s *models.Source) string {
	deref := func(p *string) string {
		if p == nil {
			return ""
		}
		return *p
	}

	var fm strings.Builder
	fm.WriteString("---\n")
	fm.WriteString(fmt.Sprintf("id: %d\n", s.ID))
	fm.WriteString(fmt.Sprintf("source_type: %s\n", s.SourceType))
	fm.WriteString(fmt.Sprintf("name: %s\n", s.Name))
	fm.WriteString(fmt.Sprintf("author: %s\n", deref(s.Author)))
	if s.Year != nil {
		fm.WriteString(fmt.Sprintf("year: %d\n", *s.Year))
	} else {
		fm.WriteString("year:\n")
	}
	fm.WriteString(fmt.Sprintf("url: %s\n", deref(s.URL)))
	fm.WriteString(fmt.Sprintf("isbn: %s\n", deref(s.ISBN)))
	fm.WriteString(fmt.Sprintf("doi: %s\n", deref(s.DOI)))
	fm.WriteString(fmt.Sprintf("license: %s\n", deref(s.License)))
	fm.WriteString(fmt.Sprintf("license_url: %s\n", deref(s.LicenseURL)))
	fm.WriteString("---\n\n")

	var body strings.Builder
	body.WriteString(fmt.Sprintf("# Description\n\n%s\n\n", deref(s.Description)))
	body.WriteString(fmt.Sprintf("# Notes\n\n%s\n", deref(s.Notes)))

	return fm.String() + body.String()
}

// sourceFrontmatter is the structured data from source frontmatter
type sourceFrontmatter struct {
	ID         int64  `yaml:"id"`
	SourceType string `yaml:"source_type"`
	Name       string `yaml:"name"`
	Author     string `yaml:"author"`
	Year       *int   `yaml:"year"`
	URL        string `yaml:"url"`
	ISBN       string `yaml:"isbn"`
	DOI        string `yaml:"doi"`
	License    string `yaml:"license"`
	LicenseURL string `yaml:"license_url"`
}

// parseSourceMarkdown parses markdown content back into a Source
func parseSourceMarkdown(content string) (*models.Source, error) {
	fm, body, err := parseFrontmatter(content)
	if err != nil {
		return nil, err
	}

	var fmData sourceFrontmatter
	if err := yaml.Unmarshal([]byte(fm), &fmData); err != nil {
		return nil, fmt.Errorf("failed to parse frontmatter: %w", err)
	}

	result := &models.Source{
		ID:         fmData.ID,
		SourceType: fmData.SourceType,
		Name:       fmData.Name,
		Year:       fmData.Year,
	}

	setIfNotEmpty := func(field **string, value string) {
		if value != "" {
			*field = &value
		}
	}

	setIfNotEmpty(&result.Author, fmData.Author)
	setIfNotEmpty(&result.URL, fmData.URL)
	setIfNotEmpty(&result.ISBN, fmData.ISBN)
	setIfNotEmpty(&result.DOI, fmData.DOI)
	setIfNotEmpty(&result.License, fmData.License)
	setIfNotEmpty(&result.LicenseURL, fmData.LicenseURL)

	// Extract text sections from body
	if desc := extractSection(body, "Description"); desc != "" {
		result.Description = &desc
	}
	if notes := extractSection(body, "Notes"); notes != "" {
		result.Notes = &notes
	}

	return result, nil
}

// EditSpeciesSource edits source-attributed data for a species
func EditSpeciesSource(ss *models.SpeciesSource, sourceName string) (*models.SpeciesSource, error) {
	content := speciesSourceToMarkdown(ss, sourceName)

	for {
		editedContent, err := openEditorMarkdown(content)
		if err != nil {
			return nil, err
		}

		edited, err := parseSpeciesSourceMarkdown(editedContent, ss)
		if err != nil {
			fmt.Fprintf(os.Stderr, "\nFailed to parse markdown: %v\n", err)
			fmt.Fprintln(os.Stderr, "Press Enter to re-open the editor and fix the error...")
			waitForEnter()
			content = editedContent
			continue
		}

		return edited, nil
	}
}

// speciesSourceToMarkdown generates a markdown string for editing species source data
func speciesSourceToMarkdown(ss *models.SpeciesSource, sourceName string) string {
	deref := func(p *string) string {
		if p == nil {
			return ""
		}
		return *p
	}

	// Build frontmatter for structured data
	var fm strings.Builder
	fm.WriteString("---\n")
	fm.WriteString(fmt.Sprintf("species: %s\n", ss.ScientificName))
	fm.WriteString(fmt.Sprintf("source: \"%s (ID: %d)\"\n", sourceName, ss.SourceID))

	// Always use inline array format for consistency
	if len(ss.LocalNames) == 0 {
		fm.WriteString("local_names: []\n")
	} else {
		// Quote names that contain special YAML characters
		quotedNames := make([]string, len(ss.LocalNames))
		for i, ln := range ss.LocalNames {
			if strings.ContainsAny(ln, ",:[]{}#&*!|>'\"%@`") || strings.HasPrefix(ln, "-") || strings.HasPrefix(ln, " ") {
				quotedNames[i] = fmt.Sprintf("%q", ln)
			} else {
				quotedNames[i] = ln
			}
		}
		fm.WriteString(fmt.Sprintf("local_names: [%s]\n", strings.Join(quotedNames, ", ")))
	}

	fm.WriteString(fmt.Sprintf("is_preferred: %t\n", ss.IsPreferred))
	if url := deref(ss.URL); url != "" {
		fm.WriteString(fmt.Sprintf("url: %s\n", url))
	} else {
		fm.WriteString("url:\n")
	}
	fm.WriteString("---\n\n")

	// Build markdown body for text content
	var body strings.Builder

	sections := []struct {
		heading string
		content string
	}{
		{"Range", deref(ss.Range)},
		{"Growth Habit", deref(ss.GrowthHabit)},
		{"Leaves", deref(ss.Leaves)},
		{"Flowers", deref(ss.Flowers)},
		{"Fruits", deref(ss.Fruits)},
		{"Bark", deref(ss.Bark)},
		{"Twigs", deref(ss.Twigs)},
		{"Buds", deref(ss.Buds)},
		{"Hardiness & Habitat", deref(ss.HardinessHabitat)},
		{"Notes", deref(ss.Miscellaneous)},
	}

	for _, s := range sections {
		body.WriteString(fmt.Sprintf("# %s\n\n%s\n\n", s.heading, s.content))
	}

	return fm.String() + body.String()
}

// speciesSourceFrontmatter is the structured data from frontmatter
type speciesSourceFrontmatter struct {
	Species     string   `yaml:"species"`
	Source      string   `yaml:"source"`
	LocalNames  []string `yaml:"local_names"`
	IsPreferred bool     `yaml:"is_preferred"`
	URL         string   `yaml:"url"`
}

// parseSpeciesSourceMarkdown parses markdown content back into a SpeciesSource
func parseSpeciesSourceMarkdown(content string, original *models.SpeciesSource) (*models.SpeciesSource, error) {
	fm, body, err := parseFrontmatter(content)
	if err != nil {
		return nil, err
	}

	var fmData speciesSourceFrontmatter
	if err := yaml.Unmarshal([]byte(fm), &fmData); err != nil {
		return nil, fmt.Errorf("failed to parse frontmatter: %w", err)
	}

	// Create result, preserving identity fields from original
	result := &models.SpeciesSource{
		ID:             original.ID,
		ScientificName: original.ScientificName,
		SourceID:       original.SourceID,
		LocalNames:     fmData.LocalNames,
		IsPreferred:    fmData.IsPreferred,
	}

	// Parse URL from frontmatter
	if fmData.URL != "" {
		result.URL = &fmData.URL
	}

	// Extract text sections from body
	setIfNotEmpty := func(field **string, heading string) {
		if content := extractSection(body, heading); content != "" {
			*field = &content
		}
	}

	setIfNotEmpty(&result.Range, "Range")
	setIfNotEmpty(&result.GrowthHabit, "Growth Habit")
	setIfNotEmpty(&result.Leaves, "Leaves")
	setIfNotEmpty(&result.Flowers, "Flowers")
	setIfNotEmpty(&result.Fruits, "Fruits")
	setIfNotEmpty(&result.Bark, "Bark")
	setIfNotEmpty(&result.Twigs, "Twigs")
	setIfNotEmpty(&result.Buds, "Buds")
	setIfNotEmpty(&result.HardinessHabitat, "Hardiness & Habitat")
	setIfNotEmpty(&result.Miscellaneous, "Notes")

	return result, nil
}

// NewSource creates a new source entry interactively
func NewSource() (*models.Source, error) {
	reader := bufio.NewReader(os.Stdin)

	prompt := func(label string) (string, error) {
		fmt.Printf("%s: ", label)
		text, err := reader.ReadString('\n')
		if err != nil {
			return "", err
		}
		// Trim newline
		if len(text) > 0 && text[len(text)-1] == '\n' {
			text = text[:len(text)-1]
		}
		if len(text) > 0 && text[len(text)-1] == '\r' {
			text = text[:len(text)-1]
		}
		return text, nil
	}

	fmt.Println("Creating new source...")

	sourceType, err := prompt("Source Type (Book, Paper, Website, Observation, etc.)")
	if err != nil {
		return nil, err
	}

	name, err := prompt("Name/Title")
	if err != nil {
		return nil, err
	}

	description, err := prompt("Description (optional)")
	if err != nil {
		return nil, err
	}

	author, err := prompt("Author (optional)")
	if err != nil {
		return nil, err
	}

	yearStr, err := prompt("Year (optional)")
	if err != nil {
		return nil, err
	}

	url, err := prompt("URL (optional)")
	if err != nil {
		return nil, err
	}

	isbn, err := prompt("ISBN (optional)")
	if err != nil {
		return nil, err
	}

	doi, err := prompt("DOI (optional)")
	if err != nil {
		return nil, err
	}

	license, err := prompt("License (optional, e.g., CC BY-NC 4.0)")
	if err != nil {
		return nil, err
	}

	licenseURL, err := prompt("License URL (optional)")
	if err != nil {
		return nil, err
	}

	notes, err := prompt("Notes (optional)")
	if err != nil {
		return nil, err
	}

	source := models.NewSource(sourceType, name)

	if description != "" {
		source.Description = &description
	}
	if author != "" {
		source.Author = &author
	}
	if yearStr != "" {
		var year int
		if _, err := fmt.Sscanf(yearStr, "%d", &year); err == nil {
			source.Year = &year
		}
	}
	if url != "" {
		source.URL = &url
	}
	if isbn != "" {
		source.ISBN = &isbn
	}
	if doi != "" {
		source.DOI = &doi
	}
	if license != "" {
		source.License = &license
	}
	if licenseURL != "" {
		source.LicenseURL = &licenseURL
	}
	if notes != "" {
		source.Notes = &notes
	}

	return source, nil
}
