import SwiftUI

/// Main list view showing all species notes
struct NotesListView: View {
    @Bindable var viewModel: NotesViewModel
    @State private var showingNewNote = false
    @State private var selectedNote: SpeciesNote?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading notes...")
                } else if viewModel.filteredNotes.isEmpty {
                    emptyStateView
                } else {
                    notesList
                }
            }
            .navigationTitle("Oak Notes")
            .searchable(text: $viewModel.searchText, prompt: "Search species")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewNote = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewNote) {
                NewNoteSheet(viewModel: viewModel)
            }
            .task {
                await viewModel.loadNotes()
            }
            .refreshable {
                await viewModel.loadNotes()
            }
        }
    }

    @MainActor
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Notes", systemImage: "leaf")
        } description: {
            if viewModel.searchText.isEmpty {
                Text("Tap + to create your first species note")
            } else {
                Text("No species match '\(viewModel.searchText)'")
            }
        } actions: {
            if viewModel.searchText.isEmpty {
                Button("Create Note") {
                    showingNewNote = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @MainActor
    private var notesList: some View {
        List {
            ForEach(viewModel.notesBySubgenus, id: \.subgenus) { section in
                Section(section.subgenus) {
                    ForEach(section.notes) { note in
                        NoteRowView(note: note)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedNote = note
                            }
                    }
                    .onDelete { offsets in
                        let notesToDelete = offsets.map { section.notes[$0] }
                        Task {
                            for note in notesToDelete {
                                await viewModel.deleteNote(note)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(item: $selectedNote) { note in
            NoteDetailView(note: note, viewModel: viewModel)
        }
    }
}

/// Row view for a single note in the list
struct NoteRowView: View {
    let note: SpeciesNote

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.scientificName)
                .font(.headline)
                .italic()

            if let commonNames = note.commonNames, !commonNames.isEmpty {
                Text(commonNames)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Label("\(note.filledFieldCount)", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if !note.photoFileNames.isEmpty {
                    Label("\(note.photoFileNames.count)", systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text(note.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Placeholder detail view (will be expanded in editor task)
struct NoteDetailView: View {
    let note: SpeciesNote
    @Bindable var viewModel: NotesViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.scientificName)
                        .font(.title)
                        .italic()

                    if let common = note.commonNames {
                        Text(common)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    Text(note.taxonomy.displayPath)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal)

                Divider()

                // Fields
                ForEach(NoteSection.allCases, id: \.self) { section in
                    let fieldsWithContent = section.fields.filter { note.hasContent(for: $0) }
                    if !fieldsWithContent.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.displayName)
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(fieldsWithContent, id: \.self) { field in
                                if let content = note.content(for: field) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Label(field.displayName, systemImage: field.iconName)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)

                                        Text(content)
                                            .font(.body)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                if note.filledFieldCount == 0 {
                    ContentUnavailableView {
                        Label("No Content", systemImage: "doc")
                    } description: {
                        Text("This note is empty. Tap Edit to add content.")
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink("Edit") {
                    Text("Editor coming soon...")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NotesListView(viewModel: NotesViewModel())
}
