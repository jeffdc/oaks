import Foundation
import SwiftUI

/// Observable view model for managing data sources
@MainActor
@Observable
final class SourcesViewModel {
    var sources: [Source] = []
    var isLoading = false
    var errorMessage: String?
    var searchText = ""

    /// Filtered sources based on search text
    var filteredSources: [Source] {
        guard !searchText.isEmpty else { return sources }
        let query = searchText.lowercased()
        return sources.filter { source in
            source.name.lowercased().contains(query) ||
            (source.author?.lowercased().contains(query) ?? false) ||
            (source.description?.lowercased().contains(query) ?? false)
        }
    }

    /// Sources grouped by type for sectioned display
    var sourcesByType: [(type: SourceType, sources: [Source])] {
        let grouped = Dictionary(grouping: filteredSources) { $0.sourceType }
        return grouped.sorted { $0.key.displayName < $1.key.displayName }
            .map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
    }

    /// Load all sources from storage
    func loadSources() async {
        isLoading = true
        errorMessage = nil

        do {
            sources = try await StorageService.shared.loadSources()
        } catch {
            errorMessage = "Failed to load sources: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Create a new source
    func createSource(
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
    ) async -> Source? {
        // Create with placeholder ID (will be replaced by storage)
        let newSource = Source(
            id: 0,
            sourceType: sourceType,
            name: name,
            description: description,
            author: author,
            year: year,
            url: url,
            isbn: isbn,
            doi: doi,
            license: license,
            licenseUrl: licenseUrl
        )

        do {
            sources = try await StorageService.shared.addSource(newSource)
            return sources.last
        } catch {
            errorMessage = "Failed to create source: \(error.localizedDescription)"
            return nil
        }
    }

    /// Update an existing source
    func updateSource(_ source: Source) async {
        do {
            sources = try await StorageService.shared.updateSource(source)
        } catch {
            errorMessage = "Failed to update source: \(error.localizedDescription)"
        }
    }

    /// Delete a source
    func deleteSource(_ source: Source) async {
        do {
            sources = try await StorageService.shared.deleteSource(id: source.id)
        } catch {
            errorMessage = "Failed to delete source: \(error.localizedDescription)"
        }
    }

    /// Delete sources at index set (for swipe-to-delete)
    func deleteSources(at offsets: IndexSet, in sources: [Source]) async {
        let sourcesToDelete = offsets.map { sources[$0] }
        for source in sourcesToDelete {
            await deleteSource(source)
        }
    }
}
