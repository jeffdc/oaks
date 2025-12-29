import SwiftUI

/// Sheet for creating a new species note
struct NewNoteSheet: View {
    @Bindable var viewModel: NotesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedSpecies: SpeciesReference?
    @State private var isCreating = false
    @State private var showingSuggestions = false

    // Manual entry fallback
    @State private var manualMode = false
    @State private var manualSpeciesName = ""
    @State private var manualSubgenus = "Quercus"
    @State private var manualSection = "Quercus"

    // Source selection
    @State private var sources: [Source] = []
    @State private var selectedSourceId: Int?

    private let taxonomyService = TaxonomyService.shared

    var body: some View {
        NavigationStack {
            Form {
                if !manualMode {
                    speciesSearchSection
                } else {
                    manualEntrySection
                }

                sourceSection

                Section {
                    Toggle("Manual entry", isOn: $manualMode)
                        .onChange(of: manualMode) { _, newValue in
                            if newValue {
                                selectedSpecies = nil
                                searchText = ""
                            } else {
                                manualSpeciesName = ""
                            }
                        }

                    Text("Use manual entry if the species isn't in the database yet.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createNote()
                        }
                    }
                    .disabled(!canCreate || isCreating)
                }
            }
            .interactiveDismissDisabled(isCreating)
            .task {
                await taxonomyService.loadData()
                await loadSources()
            }
        }
    }

    // MARK: - Source Section

    private var sourceSection: some View {
        Section("Source") {
            Picker("Source", selection: $selectedSourceId) {
                Text("None")
                    .tag(nil as Int?)

                ForEach(sources) { source in
                    Label(source.displayName, systemImage: source.iconName)
                        .tag(source.id as Int?)
                }
            }

            if let sourceId = selectedSourceId,
               let source = sources.first(where: { $0.id == sourceId }) {
                HStack {
                    Image(systemName: source.iconName)
                        .foregroundStyle(.secondary)
                    Text(source.sourceType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func loadSources() async {
        do {
            sources = try await StorageService.shared.loadSources()
            // Default to Oak Compendium (personal observation) if available
            if let oakCompendium = sources.first(where: { $0.id == 3 }) {
                selectedSourceId = oakCompendium.id
            }
        } catch {
            // Silently fail - source is optional
        }
    }

    // MARK: - Species Search Section

    private var speciesSearchSection: some View {
        Section("Species") {
            TextField("Search species...", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: searchText) { _, _ in
                    selectedSpecies = nil
                }

            if let species = selectedSpecies {
                selectedSpeciesView(species)
            } else if !searchText.isEmpty {
                suggestionsList
            } else {
                Text("Type to search \(taxonomyService.species.count) species")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func selectedSpeciesView(_ species: SpeciesReference) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(species.scientificName)
                        .font(.headline)
                        .italic()

                    if let author = species.author {
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    selectedSpecies = nil
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if let subgenus = species.taxonomy.subgenus,
               let section = species.taxonomy.section {
                Text("\(subgenus) › \(section)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let status = species.conservationStatus {
                ConservationBadge(status: status)
            }
        }
        .padding(.vertical, 4)
    }

    private var suggestionsList: some View {
        let suggestions = taxonomyService.searchSpecies(query: searchText)

        return Group {
            if suggestions.isEmpty {
                Text("No species found matching '\(searchText)'")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(suggestions) { species in
                    Button {
                        selectedSpecies = species
                        searchText = species.name
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(species.scientificName)
                                    .font(.subheadline)
                                    .italic()
                                    .foregroundStyle(.primary)

                                if let subgenus = species.taxonomy.subgenus {
                                    Text(subgenus)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer()

                            if let status = species.conservationStatus {
                                ConservationBadge(status: status)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Manual Entry Section

    private var manualEntrySection: some View {
        Group {
            Section("Species") {
                TextField("Species epithet", text: $manualSpeciesName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Text("Quercus \(manualSpeciesName.isEmpty ? "..." : manualSpeciesName)")
                    .italic()
                    .foregroundStyle(.secondary)
            }

            Section("Taxonomy") {
                Picker("Subgenus", selection: $manualSubgenus) {
                    ForEach(taxonomyService.subgenera, id: \.self) { s in
                        Text(s).tag(s)
                    }
                }

                Picker("Section", selection: $manualSection) {
                    ForEach(taxonomyService.sections(forSubgenus: manualSubgenus), id: \.self) { s in
                        Text(s).tag(s)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var canCreate: Bool {
        if manualMode {
            return !manualSpeciesName.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return selectedSpecies != nil
        }
    }

    private func createNote() async {
        isCreating = true

        let taxonomy: TaxonomyPath
        if let species = selectedSpecies {
            taxonomy = species.taxonomy.toPath(species: species.name)
        } else {
            taxonomy = TaxonomyPath(
                subgenus: manualSubgenus,
                section: manualSection,
                species: manualSpeciesName.trimmingCharacters(in: .whitespaces).lowercased()
            )
        }

        if await viewModel.createNote(taxonomy: taxonomy, sourceId: selectedSourceId) != nil {
            dismiss()
        }

        isCreating = false
    }
}

// MARK: - Conservation Status Badge

struct ConservationBadge: View {
    let status: String

    var body: some View {
        Text(status)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status.uppercased() {
        case "CR": return .red.opacity(0.2)
        case "EN": return .orange.opacity(0.2)
        case "VU": return .yellow.opacity(0.2)
        case "NT": return .blue.opacity(0.2)
        case "LC": return .green.opacity(0.2)
        case "DD": return .gray.opacity(0.2)
        default: return .gray.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status.uppercased() {
        case "CR": return .red
        case "EN": return .orange
        case "VU": return .yellow
        case "NT": return .blue
        case "LC": return .green
        case "DD": return .gray
        default: return .gray
        }
    }
}

#Preview {
    NewNoteSheet(viewModel: NotesViewModel())
}
