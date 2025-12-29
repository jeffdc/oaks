import SwiftUI

/// Main list view showing all data sources
struct SourcesListView: View {
    @Bindable var viewModel: SourcesViewModel
    @State private var showingNewSource = false
    @State private var selectedSource: Source?
    @State private var sourceToEdit: Source?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading sources...")
                } else if viewModel.filteredSources.isEmpty {
                    emptyStateView
                } else {
                    sourcesList
                }
            }
            .navigationTitle("Sources")
            .searchable(text: $viewModel.searchText, prompt: "Search sources")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewSource = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewSource) {
                SourceFormSheet(viewModel: viewModel, source: nil)
            }
            .sheet(item: $sourceToEdit) { source in
                SourceFormSheet(viewModel: viewModel, source: source)
            }
            .task {
                await viewModel.loadSources()
            }
            .refreshable {
                await viewModel.loadSources()
            }
        }
    }

    @MainActor
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Sources", systemImage: "books.vertical")
        } description: {
            if viewModel.searchText.isEmpty {
                Text("Tap + to add your first source")
            } else {
                Text("No sources match '\(viewModel.searchText)'")
            }
        } actions: {
            if viewModel.searchText.isEmpty {
                Button("Add Source") {
                    showingNewSource = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @MainActor
    private var sourcesList: some View {
        List {
            ForEach(viewModel.sourcesByType, id: \.type) { section in
                Section {
                    ForEach(section.sources) { source in
                        SourceRowView(source: source)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSource = source
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteSource(source)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    sourceToEdit = source
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                } header: {
                    Label(section.type.displayName, systemImage: section.type.iconName)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(item: $selectedSource) { source in
            SourceDetailView(source: source, viewModel: viewModel)
        }
    }
}

/// Row view for a single source in the list
struct SourceRowView: View {
    let source: Source

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: source.iconName)
                    .foregroundStyle(.secondary)

                Text(source.name)
                    .font(.headline)
            }

            if let author = source.author {
                Text(author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let description = source.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Detail view for a source
struct SourceDetailView: View {
    let source: Source
    @Bindable var viewModel: SourcesViewModel
    @State private var showingEditSheet = false

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Type") {
                    Label(source.sourceType.displayName, systemImage: source.iconName)
                }

                LabeledContent("Name", value: source.name)

                if let author = source.author {
                    LabeledContent("Author", value: author)
                }

                if let year = source.year {
                    LabeledContent("Year", value: String(year))
                }

                if let description = source.description {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(description)
                    }
                }
            }

            if source.url != nil || source.isbn != nil || source.doi != nil {
                Section("References") {
                    if let url = source.url, let link = URL(string: url) {
                        Link(destination: link) {
                            LabeledContent("URL") {
                                Text(url)
                                    .lineLimit(1)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }

                    if let isbn = source.isbn {
                        LabeledContent("ISBN", value: isbn)
                    }

                    if let doi = source.doi {
                        LabeledContent("DOI", value: doi)
                    }
                }
            }

            if source.license != nil || source.licenseUrl != nil {
                Section("License") {
                    if let license = source.license {
                        LabeledContent("License", value: license)
                    }

                    if let licenseUrl = source.licenseUrl, let link = URL(string: licenseUrl) {
                        Link(destination: link) {
                            LabeledContent("License URL") {
                                Text(licenseUrl)
                                    .lineLimit(1)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(source.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            SourceFormSheet(viewModel: viewModel, source: source)
        }
    }
}

#Preview {
    SourcesListView(viewModel: SourcesViewModel())
}
