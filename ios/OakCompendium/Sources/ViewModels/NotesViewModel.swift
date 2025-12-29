import Foundation
import SwiftUI

/// Observable view model for managing species notes
@MainActor
@Observable
final class NotesViewModel {
    var notes: [SpeciesNote] = []
    var isLoading = false
    var errorMessage: String?
    var searchText = ""

    /// Filtered notes based on search text
    var filteredNotes: [SpeciesNote] {
        guard !searchText.isEmpty else { return notes }
        let query = searchText.lowercased()
        return notes.filter { note in
            note.scientificName.lowercased().contains(query) ||
            (note.commonNames?.lowercased().contains(query) ?? false)
        }
    }

    /// Notes grouped by subgenus for sectioned display
    var notesBySubgenus: [(subgenus: String, notes: [SpeciesNote])] {
        let grouped = Dictionary(grouping: filteredNotes) { $0.taxonomy.subgenus }
        return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value.sorted { $0.scientificName < $1.scientificName }) }
    }

    /// Load all notes from storage
    func loadNotes() async {
        isLoading = true
        errorMessage = nil

        do {
            notes = try await StorageService.shared.loadNotes()
        } catch {
            errorMessage = "Failed to load notes: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Create a new note
    func createNote(taxonomy: TaxonomyPath, sourceId: Int? = nil) async -> SpeciesNote? {
        let newNote = SpeciesNote(taxonomy: taxonomy, sourceId: sourceId)

        do {
            notes = try await StorageService.shared.addNote(newNote)
            return newNote
        } catch {
            errorMessage = "Failed to create note: \(error.localizedDescription)"
            return nil
        }
    }

    /// Update an existing note
    func updateNote(_ note: SpeciesNote) async {
        do {
            notes = try await StorageService.shared.updateNote(note)
        } catch {
            errorMessage = "Failed to update note: \(error.localizedDescription)"
        }
    }

    /// Delete a note
    func deleteNote(_ note: SpeciesNote) async {
        do {
            notes = try await StorageService.shared.deleteNote(id: note.id)
        } catch {
            errorMessage = "Failed to delete note: \(error.localizedDescription)"
        }
    }

    /// Delete notes at index set (for swipe-to-delete)
    func deleteNotes(at offsets: IndexSet) async {
        let notesToDelete = offsets.map { filteredNotes[$0] }
        for note in notesToDelete {
            await deleteNote(note)
        }
    }
}
