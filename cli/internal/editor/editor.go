package editor

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"

	"github.com/jeff/oaks/cli/internal/models"
	"github.com/jeff/oaks/cli/internal/schema"
	"gopkg.in/yaml.v3"
)

// getEditor returns the user's preferred editor
func getEditor() string {
	if editor := os.Getenv("EDITOR"); editor != "" {
		return editor
	}
	return "vi"
}

// openEditor opens the editor with the given content and returns the edited content
func openEditor(initialContent string) (string, error) {
	editor := getEditor()

	tmpFile, err := os.CreateTemp("", "oak-*.yaml")
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

// waitForEnter waits for the user to press Enter
func waitForEnter() {
	reader := bufio.NewReader(os.Stdin)
	reader.ReadString('\n')
}

// EditOakEntry edits an Oak entry with validation loop
func EditOakEntry(entry *models.OakEntry, validator *schema.Validator) (*models.OakEntry, error) {
	yamlContent, err := yaml.Marshal(entry)
	if err != nil {
		return nil, fmt.Errorf("failed to serialize entry to YAML: %w", err)
	}

	content := string(yamlContent)

	for {
		editedYAML, err := openEditor(content)
		if err != nil {
			return nil, err
		}

		var editedEntry models.OakEntry
		if err := yaml.Unmarshal([]byte(editedYAML), &editedEntry); err != nil {
			fmt.Fprintf(os.Stderr, "\nFailed to parse YAML: %v\n", err)
			fmt.Fprintln(os.Stderr, "Press Enter to re-open the editor and fix the error...")
			waitForEnter()
			content = editedYAML
			continue
		}

		if err := validator.ValidateOakEntry(&editedEntry); err != nil {
			fmt.Fprintf(os.Stderr, "\nValidation failed:\n%v\n", err)
			fmt.Fprintln(os.Stderr, "\nPress Enter to re-open the editor and fix the errors...")
			waitForEnter()
			content = editedYAML
			continue
		}

		return &editedEntry, nil
	}
}

// NewOakEntry creates a new Oak entry with validation loop
func NewOakEntry(scientificName string, validator *schema.Validator) (*models.OakEntry, error) {
	template := models.NewOakEntry(scientificName)
	return EditOakEntry(template, validator)
}

// EditSource edits a Source entry
func EditSource(source *models.Source) (*models.Source, error) {
	// Generate YAML with all fields shown explicitly
	content := sourceToYAML(source)
	originalID := source.ID

	for {
		editedYAML, err := openEditor(content)
		if err != nil {
			return nil, err
		}

		var editedSource models.Source
		if err := yaml.Unmarshal([]byte(editedYAML), &editedSource); err != nil {
			fmt.Fprintf(os.Stderr, "\nFailed to parse YAML: %v\n", err)
			fmt.Fprintln(os.Stderr, "Press Enter to re-open the editor and fix the error...")
			waitForEnter()
			content = editedYAML
			continue
		}

		// Reject ID changes
		if editedSource.ID != originalID {
			fmt.Fprintf(os.Stderr, "\nID cannot be changed (was %d, attempted %d)\n", originalID, editedSource.ID)
			fmt.Fprintln(os.Stderr, "Press Enter to re-open the editor and fix the error...")
			waitForEnter()
			content = editedYAML
			continue
		}

		if editedSource.Name == "" {
			fmt.Fprintln(os.Stderr, "\nname cannot be empty")
			fmt.Fprintln(os.Stderr, "Press Enter to re-open the editor and fix the error...")
			waitForEnter()
			content = editedYAML
			continue
		}

		if editedSource.SourceType == "" {
			fmt.Fprintln(os.Stderr, "\nsource_type cannot be empty")
			fmt.Fprintln(os.Stderr, "Press Enter to re-open the editor and fix the error...")
			waitForEnter()
			content = editedYAML
			continue
		}

		return &editedSource, nil
	}
}

// sourceToYAML generates a YAML string with all fields shown explicitly
func sourceToYAML(s *models.Source) string {
	deref := func(p *string) string {
		if p == nil {
			return ""
		}
		return *p
	}
	derefInt := func(p *int) string {
		if p == nil {
			return ""
		}
		return fmt.Sprintf("%d", *p)
	}

	return fmt.Sprintf(`# Source Entry (ID cannot be changed)
id: %d
source_type: %s
name: %s
description: %s
author: %s
year: %s
url: %s
isbn: %s
doi: %s
notes: %s
`, s.ID, s.SourceType, s.Name, deref(s.Description), deref(s.Author),
		derefInt(s.Year), deref(s.URL), deref(s.ISBN), deref(s.DOI), deref(s.Notes))
}

// EditSpeciesSource edits source-attributed data for a species
func EditSpeciesSource(ss *models.SpeciesSource, sourceName string) (*models.SpeciesSource, error) {
	content := speciesSourceToYAML(ss, sourceName)
	originalName := ss.ScientificName
	originalSourceID := ss.SourceID

	for {
		editedYAML, err := openEditor(content)
		if err != nil {
			return nil, err
		}

		var edited models.SpeciesSource
		if err := yaml.Unmarshal([]byte(editedYAML), &edited); err != nil {
			fmt.Fprintf(os.Stderr, "\nFailed to parse YAML: %v\n", err)
			fmt.Fprintln(os.Stderr, "Press Enter to re-open the editor and fix the error...")
			waitForEnter()
			content = editedYAML
			continue
		}

		// Preserve identity fields (cannot be changed)
		edited.ScientificName = originalName
		edited.SourceID = originalSourceID
		edited.ID = ss.ID

		return &edited, nil
	}
}

// speciesSourceToYAML generates a YAML string for editing species source data
func speciesSourceToYAML(ss *models.SpeciesSource, sourceName string) string {
	deref := func(p *string) string {
		if p == nil {
			return ""
		}
		return *p
	}

	localNames := ""
	if len(ss.LocalNames) > 0 {
		for _, ln := range ss.LocalNames {
			localNames += fmt.Sprintf("\n  - %s", ln)
		}
	}

	isPreferred := "false"
	if ss.IsPreferred {
		isPreferred = "true"
	}

	return fmt.Sprintf(`# Source Data for: %s
# Source: %s (ID: %d)
#
# Species name and source ID cannot be changed here.
# Leave fields empty if no data available.

# Local/common names for this species
local_names:%s

# Geographic range
range: %s

# Growth habit (tree size, form)
growth_habit: %s

# Leaf description
leaves: %s

# Flower description
flowers: %s

# Fruit/acorn description
fruits: %s

# Bark description
bark: %s

# Twig description
twigs: %s

# Bud description
buds: %s

# Hardiness and habitat preferences
hardiness_habitat: %s

# Other notes
miscellaneous: %s

# URL for this specific source page (if applicable)
url: %s

# Is this the preferred/primary source for display?
is_preferred: %s
`, ss.ScientificName, sourceName, ss.SourceID,
		localNames,
		deref(ss.Range),
		deref(ss.GrowthHabit),
		deref(ss.Leaves),
		deref(ss.Flowers),
		deref(ss.Fruits),
		deref(ss.Bark),
		deref(ss.Twigs),
		deref(ss.Buds),
		deref(ss.HardinessHabitat),
		deref(ss.Miscellaneous),
		deref(ss.URL),
		isPreferred)
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
	if notes != "" {
		source.Notes = &notes
	}

	return source, nil
}
