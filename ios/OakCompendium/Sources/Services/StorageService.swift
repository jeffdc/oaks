import Foundation

/// Actor-based service for persisting species notes to local JSON storage
actor StorageService {
    static let shared = StorageService()

    private let fileName = "species_notes.json"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - File URLs

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var notesFileURL: URL {
        documentsDirectory.appendingPathComponent(fileName)
    }

    var photosDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - CRUD Operations

    /// Load all notes from storage
    func loadNotes() async throws -> [SpeciesNote] {
        guard FileManager.default.fileExists(atPath: notesFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: notesFileURL)
        return try decoder.decode([SpeciesNote].self, from: data)
    }

    /// Save all notes to storage
    func saveNotes(_ notes: [SpeciesNote]) async throws {
        let data = try encoder.encode(notes)
        try data.write(to: notesFileURL, options: .atomic)
    }

    /// Add a new note
    func addNote(_ note: SpeciesNote) async throws -> [SpeciesNote] {
        var notes = try await loadNotes()
        notes.append(note)
        try await saveNotes(notes)
        return notes
    }

    /// Update an existing note
    func updateNote(_ note: SpeciesNote) async throws -> [SpeciesNote] {
        var notes = try await loadNotes()
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
            try await saveNotes(notes)
        }
        return notes
    }

    /// Delete a note by ID
    func deleteNote(id: UUID) async throws -> [SpeciesNote] {
        var notes = try await loadNotes()
        notes.removeAll { $0.id == id }
        try await saveNotes(notes)
        return notes
    }

    /// Find a note by ID
    func findNote(id: UUID) async throws -> SpeciesNote? {
        let notes = try await loadNotes()
        return notes.first { $0.id == id }
    }

    /// Find notes by species name (partial match)
    func findNotes(matching query: String) async throws -> [SpeciesNote] {
        let notes = try await loadNotes()
        let lowercased = query.lowercased()
        return notes.filter { note in
            note.scientificName.lowercased().contains(lowercased) ||
            (note.commonNames?.lowercased().contains(lowercased) ?? false)
        }
    }

    // MARK: - Photo Management

    /// Save a photo and return its filename
    func savePhoto(_ imageData: Data, for noteId: UUID) async throws -> String {
        let fileName = "\(noteId.uuidString)_\(UUID().uuidString).jpg"
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        try imageData.write(to: fileURL)
        return fileName
    }

    /// Get URL for a photo filename
    func photoURL(for fileName: String) -> URL {
        photosDirectory.appendingPathComponent(fileName)
    }

    /// Delete a photo file
    func deletePhoto(fileName: String) async throws {
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        try FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Export

    /// Export notes as JSON data (for iCloud/sharing)
    func exportNotesData() async throws -> Data {
        let notes = try await loadNotes()
        return try encoder.encode(notes)
    }

    /// Import notes from JSON data
    func importNotes(from data: Data, merge: Bool = true) async throws -> [SpeciesNote] {
        let imported = try decoder.decode([SpeciesNote].self, from: data)

        if merge {
            var existing = try await loadNotes()
            let existingIds = Set(existing.map(\.id))

            for note in imported {
                if existingIds.contains(note.id) {
                    // Update existing note if imported version is newer
                    if let index = existing.firstIndex(where: { $0.id == note.id }),
                       note.updatedAt > existing[index].updatedAt {
                        existing[index] = note
                    }
                } else {
                    existing.append(note)
                }
            }

            try await saveNotes(existing)
            return existing
        } else {
            try await saveNotes(imported)
            return imported
        }
    }
}
