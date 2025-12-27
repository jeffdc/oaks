import Foundation

/// Represents the taxonomic classification path for an oak species
/// Follows the iNaturalist hierarchy: Quercus > Subgenus > Section > Subsection > Complex > Species
struct TaxonomyPath: Codable, Hashable, Sendable {
    let subgenus: String
    let section: String
    let subsection: String?
    let complex: String?
    let species: String

    /// Creates a taxonomy path from components
    init(subgenus: String, section: String, subsection: String? = nil, complex: String? = nil, species: String) {
        self.subgenus = subgenus
        self.section = section
        self.subsection = subsection
        self.complex = complex
        self.species = species
    }

    /// Parses a Bear-style tag path like "Quercus/Quercus/Quercus/alba"
    /// Format: #Quercus/{subgenus}/{section}/{species}
    /// Or: #Quercus/{subgenus}/{section}/{subsection}/{species}
    init?(tagPath: String) {
        let cleaned = tagPath.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let components = cleaned.split(separator: "/").map(String.init)

        // Minimum: Quercus/subgenus/section/species (4 components)
        guard components.count >= 4, components[0] == "Quercus" else {
            return nil
        }

        self.subgenus = components[1]
        self.section = components[2]

        // Last component is always species
        self.species = components[components.count - 1]

        // Middle components (if any) are subsection/complex
        if components.count == 5 {
            self.subsection = components[3]
            self.complex = nil
        } else if components.count >= 6 {
            self.subsection = components[3]
            self.complex = components[4]
        } else {
            self.subsection = nil
            self.complex = nil
        }
    }

    /// Full scientific name with genus
    var scientificName: String {
        "Quercus \(species)"
    }

    /// Bear-style tag path for export
    var tagPath: String {
        var path = "#Quercus/\(subgenus)/\(section)"
        if let subsection {
            path += "/\(subsection)"
        }
        if let complex {
            path += "/\(complex)"
        }
        path += "/\(species)"
        return path
    }

    /// Display path without the # prefix
    var displayPath: String {
        String(tagPath.dropFirst())
    }
}
