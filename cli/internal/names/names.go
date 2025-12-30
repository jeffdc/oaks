// Package names provides utilities for normalizing oak species names.
package names

import (
	"strings"
)

// NormalizeHybridName converts plain 'x' notation to the proper '×' (multiplication sign)
// for hybrid oak species. This allows users to type "x beadlei" or "alba x macrocarpa"
// on the command line without needing to input the special × character.
//
// Examples:
//   - "x beadlei" → "× beadlei"
//   - "alba x macrocarpa" → "alba × macrocarpa"
//   - "× beadlei" → "× beadlei" (unchanged)
func NormalizeHybridName(name string) string {
	// Handle leading "x " → "× "
	if strings.HasPrefix(name, "x ") {
		name = "× " + name[2:]
	}

	// Handle internal " x " → " × "
	name = strings.ReplaceAll(name, " x ", " × ")

	return name
}
