import Foundation

/// Types of data sources
enum SourceType: String, Codable, CaseIterable, Sendable {
    case website = "Website"
    case book = "Book"
    case personalObservation = "Personal Observation"
    case journalArticle = "Journal Article"
    case other = "Other"

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .website: return "globe"
        case .book: return "book"
        case .personalObservation: return "person.fill"
        case .journalArticle: return "doc.text"
        case .other: return "doc"
        }
    }

    /// Initialize from database string value
    init(fromString value: String) {
        self = SourceType.allCases.first { $0.rawValue.lowercased() == value.lowercased() } ?? .other
    }
}

/// A data source for species information
struct Source: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    var sourceType: SourceType
    var name: String
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

    init(
        id: Int,
        sourceType: SourceType,
        name: String,
        description: String? = nil,
        author: String? = nil,
        year: Int? = nil,
        url: String? = nil,
        isbn: String? = nil,
        doi: String? = nil,
        license: String? = nil,
        licenseUrl: String? = nil
    ) {
        self.id = id
        self.sourceType = sourceType
        self.name = name
        self.description = description
        self.author = author
        self.year = year
        self.url = url
        self.isbn = isbn
        self.doi = doi
        self.license = license
        self.licenseUrl = licenseUrl
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
        sourceType.iconName
    }
}

// MARK: - Sample Data

extension Source {
    static let personalObservation = Source(
        id: 3,
        sourceType: .personalObservation,
        name: "Oak Compendium",
        author: "Jeff Clark",
        year: 2025,
        license: "All Rights Reserved"
    )

    static let samples: [Source] = [
        personalObservation,
        Source(
            id: 1,
            sourceType: .website,
            name: "iNaturalist",
            url: "https://www.inaturalist.org/taxa/47851-Quercus",
            license: "CC0",
            licenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/"
        ),
        Source(
            id: 2,
            sourceType: .website,
            name: "Oaks of the World",
            description: "Comprehensive oak species database by oaksoftheworld.fr",
            url: "https://oaksoftheworld.fr",
            license: "All Rights Reserved"
        ),
        Source(
            id: 4,
            sourceType: .book,
            name: "The Sibley Guide to Trees",
            author: "David Allen Sibley",
            year: 2009,
            isbn: "978-0-375-415197",
            license: "All Rights Reserved"
        )
    ]
}
