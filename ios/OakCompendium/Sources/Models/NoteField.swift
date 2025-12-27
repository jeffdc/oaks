import Foundation

/// Enumeration of all note field types, matching the Bear note template
enum NoteField: String, CaseIterable, Codable, Sendable {
    case commonNames = "common_names"
    case leaf = "leaf"
    case acorn = "acorn"
    case bark = "bark"
    case buds = "buds"
    case form = "form"
    case rangeHabitat = "range_habitat"
    case fieldNotes = "field_notes"
    case resources = "resources"

    /// Display name for UI
    var displayName: String {
        switch self {
        case .commonNames: return "Common Name(s)"
        case .leaf: return "Leaf"
        case .acorn: return "Acorn"
        case .bark: return "Bark"
        case .buds: return "Buds"
        case .form: return "Form"
        case .rangeHabitat: return "Range & Habitat"
        case .fieldNotes: return "Field Notes"
        case .resources: return "Resources"
        }
    }

    /// Section header for grouped display
    var section: NoteSection {
        switch self {
        case .commonNames:
            return .general
        case .leaf, .acorn, .bark, .buds, .form:
            return .identification
        case .rangeHabitat:
            return .ecology
        case .fieldNotes, .resources:
            return .notes
        }
    }

    /// Placeholder text for empty fields
    var placeholder: String {
        switch self {
        case .commonNames:
            return "White oak, Eastern white oak..."
        case .leaf:
            return "Leaf shape, size, lobing, color..."
        case .acorn:
            return "Cup depth, cap scales, nut shape..."
        case .bark:
            return "Color, texture, fissuring..."
        case .buds:
            return "Size, shape, clustering..."
        case .form:
            return "Growth habit, height, crown shape..."
        case .rangeHabitat:
            return "Geographic range, elevation, soil preferences..."
        case .fieldNotes:
            return "Personal observations, identification tips..."
        case .resources:
            return "Links, references, citations..."
        }
    }

    /// Icon name (SF Symbols)
    var iconName: String {
        switch self {
        case .commonNames: return "textformat"
        case .leaf: return "leaf"
        case .acorn: return "circle.bottomhalf.filled"
        case .bark: return "tree"
        case .buds: return "sparkle"
        case .form: return "arrow.up.and.down.and.arrow.left.and.right"
        case .rangeHabitat: return "map"
        case .fieldNotes: return "note.text"
        case .resources: return "link"
        }
    }
}

/// Logical groupings for note fields
enum NoteSection: String, CaseIterable, Codable, Sendable {
    case general
    case identification
    case ecology
    case notes

    var displayName: String {
        switch self {
        case .general: return "General"
        case .identification: return "Identification"
        case .ecology: return "Ecology"
        case .notes: return "Notes"
        }
    }

    /// Fields belonging to this section
    var fields: [NoteField] {
        NoteField.allCases.filter { $0.section == self }
    }
}
