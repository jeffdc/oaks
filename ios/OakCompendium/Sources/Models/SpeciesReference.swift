import Foundation

/// Lightweight reference to a species for lists and autocomplete
struct SpeciesReference: Identifiable, Codable, Hashable, Sendable {
    var id: String { name }

    let name: String
    let author: String?
    let isHybrid: Bool
    let conservationStatus: String?
    let taxonomy: SpeciesTaxonomy

    enum CodingKeys: String, CodingKey {
        case name
        case author
        case isHybrid = "is_hybrid"
        case conservationStatus = "conservation_status"
        case taxonomy
    }

    /// Full scientific name with genus
    var scientificName: String {
        if isHybrid {
            return "Quercus × \(name)"
        }
        return "Quercus \(name)"
    }

    /// Display name for lists (name with optional author)
    var displayName: String {
        if let author, !author.isEmpty {
            return "\(scientificName) \(author)"
        }
        return scientificName
    }
}

/// Taxonomy information embedded in species
struct SpeciesTaxonomy: Codable, Hashable, Sendable {
    let genus: String?
    let subgenus: String?
    let section: String?
    let subsection: String?
    let complex: String?

    /// Converts to TaxonomyPath for note creation
    func toPath(species: String) -> TaxonomyPath {
        TaxonomyPath(
            subgenus: subgenus ?? "Unknown",
            section: section ?? "Unknown",
            subsection: subsection,
            complex: complex,
            species: species
        )
    }
}

// MARK: - Sample Data

extension SpeciesReference {
    static let sample = SpeciesReference(
        name: "alba",
        author: "L. 1753",
        isHybrid: false,
        conservationStatus: "LC",
        taxonomy: SpeciesTaxonomy(
            genus: "Quercus",
            subgenus: "Quercus",
            section: "Quercus",
            subsection: nil,
            complex: nil
        )
    )
}
