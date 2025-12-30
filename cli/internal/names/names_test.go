package names

import "testing"

func TestNormalizeHybridName(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "leading x prefix",
			input:    "x beadlei",
			expected: "× beadlei",
		},
		{
			name:     "internal x between species",
			input:    "alba x macrocarpa",
			expected: "alba × macrocarpa",
		},
		{
			name:     "already normalized leading",
			input:    "× beadlei",
			expected: "× beadlei",
		},
		{
			name:     "already normalized internal",
			input:    "alba × macrocarpa",
			expected: "alba × macrocarpa",
		},
		{
			name:     "non-hybrid species",
			input:    "alba",
			expected: "alba",
		},
		{
			name:     "species containing x in name",
			input:    "mexicana",
			expected: "mexicana",
		},
		{
			name:     "multiple x markers",
			input:    "alba x robur x petraea",
			expected: "alba × robur × petraea",
		},
		{
			name:     "x at end without space",
			input:    "mexicanax",
			expected: "mexicanax",
		},
		{
			name:     "empty string",
			input:    "",
			expected: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := NormalizeHybridName(tt.input)
			if result != tt.expected {
				t.Errorf("NormalizeHybridName(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}
