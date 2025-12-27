import Foundation

/// A data source for species information
struct Source: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let sourceType: String
    let name: String
    var description: String?
    var author: String?
    var year: Int?
    var url: String?
    var isbn: String?
    var doi: String?
    var license: String?
    var licenseUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sourceType = "source_type"
        case name
        case description
        case author
        case year
        case url
        case isbn
        case doi
        case license
        case licenseUrl = "license_url"
    }

    /// Display name with optional author
    var displayName: String {
        if let author {
            return "\(name) (\(author))"
        }
        return name
    }

    /// Icon name based on source type
    var iconName: String {
        switch sourceType.lowercased() {
        case "website":
            return "globe"
        case "book":
            return "book"
        case "personal observation":
            return "person.fill"
        case "journal article":
            return "doc.text"
        default:
            return "doc"
        }
    }
}

// MARK: - Sample Data

extension Source {
    static let personalObservation = Source(
        id: 3,
        sourceType: "Personal Observation",
        name: "Oak Compendium",
        author: "Jeff Clark",
        year: 2025,
        license: "All Rights Reserved"
    )

    static let samples: [Source] = [
        personalObservation,
        Source(
            id: 1,
            sourceType: "Website",
            name: "iNaturalist",
            url: "https://www.inaturalist.org/taxa/47851-Quercus",
            license: "CC0"
        ),
        Source(
            id: 2,
            sourceType: "Website",
            name: "Oaks of the World",
            url: "https://oaksoftheworld.fr",
            license: "All Rights Reserved"
        )
    ]
}
