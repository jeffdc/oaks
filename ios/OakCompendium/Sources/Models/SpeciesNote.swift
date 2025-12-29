import Foundation

/// A field note for a specific oak species
struct SpeciesNote: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var taxonomy: TaxonomyPath
    var fields: [NoteField: String]
    let createdAt: Date
    var updatedAt: Date

    /// Photo file names (stored in app documents directory)
    var photoFileNames: [String]

    /// ID of the source this note is attributed to
    var sourceId: Int?

    init(
        id: UUID = UUID(),
        taxonomy: TaxonomyPath,
        fields: [NoteField: String] = [:],
        photoFileNames: [String] = [],
        sourceId: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.taxonomy = taxonomy
        self.fields = fields
        self.photoFileNames = photoFileNames
        self.sourceId = sourceId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Scientific name from taxonomy
    var scientificName: String {
        taxonomy.scientificName
    }

    /// Common names if available
    var commonNames: String? {
        fields[.commonNames]
    }

    /// Display title - common name if available, otherwise scientific name
    var displayTitle: String {
        if let common = commonNames, !common.isEmpty {
            return common.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? scientificName
        }
        return scientificName
    }

    /// Check if a field has content
    func hasContent(for field: NoteField) -> Bool {
        guard let content = fields[field] else { return false }
        return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Get content for a field, or nil if empty
    func content(for field: NoteField) -> String? {
        guard hasContent(for: field) else { return nil }
        return fields[field]
    }

    /// Count of non-empty fields
    var filledFieldCount: Int {
        fields.values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    /// Update a field's content
    mutating func setContent(_ content: String, for field: NoteField) {
        fields[field] = content
        updatedAt = Date()
    }

    /// Clear a field's content
    mutating func clearContent(for field: NoteField) {
        fields.removeValue(forKey: field)
        updatedAt = Date()
    }
}

// MARK: - Codable support for NoteField dictionary keys

extension SpeciesNote {
    enum CodingKeys: String, CodingKey {
        case id, taxonomy, fields, photoFileNames, sourceId, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        taxonomy = try container.decode(TaxonomyPath.self, forKey: .taxonomy)
        photoFileNames = try container.decodeIfPresent([String].self, forKey: .photoFileNames) ?? []
        sourceId = try container.decodeIfPresent(Int.self, forKey: .sourceId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        // Decode fields dictionary with String keys, convert to NoteField
        let stringFields = try container.decode([String: String].self, forKey: .fields)
        var noteFields: [NoteField: String] = [:]
        for (key, value) in stringFields {
            if let field = NoteField(rawValue: key) {
                noteFields[field] = value
            }
        }
        fields = noteFields
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(taxonomy, forKey: .taxonomy)
        try container.encode(photoFileNames, forKey: .photoFileNames)
        try container.encodeIfPresent(sourceId, forKey: .sourceId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)

        // Encode fields dictionary with String keys
        var stringFields: [String: String] = [:]
        for (field, value) in fields {
            stringFields[field.rawValue] = value
        }
        try container.encode(stringFields, forKey: .fields)
    }
}

// MARK: - Sample Data

extension SpeciesNote {
    static let sample = SpeciesNote(
        taxonomy: TaxonomyPath(
            subgenus: "Quercus",
            section: "Quercus",
            species: "alba"
        ),
        fields: [
            .commonNames: "White oak, Eastern white oak",
            .leaf: "5-9 rounded lobes, no bristle tips. 5-9 inches long.",
            .acorn: "Shallow cup, 1/4 nut enclosed. Sweet, low tannin.",
            .bark: "Light gray, scaly plates. Distinctive whitish color.",
            .rangeHabitat: "Eastern North America. Mesic upland forests."
        ]
    )
}
