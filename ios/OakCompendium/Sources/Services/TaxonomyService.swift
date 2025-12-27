import Foundation

/// Service for loading and managing taxonomy data from bundled JSON
@Observable
final class TaxonomyService: @unchecked Sendable {
    static let shared = TaxonomyService()

    // MARK: - State

    private(set) var isLoading = false
    private(set) var error: Error?
    private(set) var sources: [Source] = []
    private(set) var species: [SpeciesReference] = []

    /// Unique subgenera from loaded species
    var subgenera: [String] {
        Array(Set(species.compactMap { $0.taxonomy.subgenus })).sorted()
    }

    /// Unique sections from loaded species
    var sections: [String] {
        Array(Set(species.compactMap { $0.taxonomy.section })).sorted()
    }

    /// Get sections for a specific subgenus
    func sections(forSubgenus subgenus: String) -> [String] {
        let filtered = species.filter { $0.taxonomy.subgenus == subgenus }
        return Array(Set(filtered.compactMap { $0.taxonomy.section })).sorted()
    }

    /// Get species for a specific subgenus and section
    func species(forSubgenus subgenus: String, section: String) -> [SpeciesReference] {
        species.filter {
            $0.taxonomy.subgenus == subgenus && $0.taxonomy.section == section
        }.sorted { $0.name < $1.name }
    }

    /// Search species by name prefix (for autocomplete)
    func searchSpecies(query: String) -> [SpeciesReference] {
        guard !query.isEmpty else { return [] }
        let lowercased = query.lowercased()
        return species.filter {
            $0.name.lowercased().hasPrefix(lowercased) ||
            $0.scientificName.lowercased().contains(lowercased)
        }.prefix(20).map { $0 }
    }

    /// Find a species by exact name
    func findSpecies(name: String) -> SpeciesReference? {
        species.first { $0.name.lowercased() == name.lowercased() }
    }

    /// Find a source by ID
    func findSource(id: Int) -> Source? {
        sources.first { $0.id == id }
    }

    // MARK: - Loading

    /// Load taxonomy data from bundled JSON
    @MainActor
    func loadData() async {
        guard species.isEmpty else { return } // Already loaded

        isLoading = true
        error = nil

        do {
            // Try to load from bundle
            guard let url = Bundle.main.url(forResource: "quercus_data", withExtension: "json") else {
                throw TaxonomyError.bundleNotFound
            }

            let data = try Data(contentsOf: url)
            let container = try JSONDecoder().decode(QuercusDataContainer.self, from: data)

            self.sources = container.sources
            self.species = container.species
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Reload data (force refresh)
    @MainActor
    func reloadData() async {
        species = []
        sources = []
        await loadData()
    }
}

// MARK: - Container for JSON structure

private struct QuercusDataContainer: Codable {
    let metadata: Metadata?
    let sources: [Source]
    let species: [SpeciesReference]

    struct Metadata: Codable {
        let version: String?
        let exportedAt: String?
        let speciesCount: Int?

        enum CodingKeys: String, CodingKey {
            case version
            case exportedAt = "exported_at"
            case speciesCount = "species_count"
        }
    }
}

// MARK: - Errors

enum TaxonomyError: LocalizedError {
    case bundleNotFound
    case invalidData

    var errorDescription: String? {
        switch self {
        case .bundleNotFound:
            return "Taxonomy data file not found in app bundle."
        case .invalidData:
            return "Could not parse taxonomy data."
        }
    }
}
