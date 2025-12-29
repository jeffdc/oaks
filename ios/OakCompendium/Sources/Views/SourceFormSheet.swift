import SwiftUI

/// Sheet for creating or editing a source
struct SourceFormSheet: View {
    @Bindable var viewModel: SourcesViewModel
    let source: Source?

    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var sourceType: SourceType = .book
    @State private var name = ""
    @State private var description = ""
    @State private var author = ""
    @State private var yearString = ""
    @State private var url = ""
    @State private var isbn = ""
    @State private var doi = ""
    @State private var license = ""
    @State private var licenseUrl = ""

    @State private var isSaving = false

    private var isEditing: Bool { source != nil }

    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                referenceSection
                licenseSection
            }
            .navigationTitle(isEditing ? "Edit Source" : "New Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        Task {
                            await saveSource()
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
            .onAppear {
                if let source {
                    populateForm(from: source)
                }
            }
        }
    }

    // MARK: - Form Sections

    private var basicInfoSection: some View {
        Section("Basic Info") {
            Picker("Type", selection: $sourceType) {
                ForEach(SourceType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.iconName)
                        .tag(type)
                }
            }

            TextField("Name", text: $name)

            TextField("Author", text: $author)

            TextField("Year", text: $yearString)
                .keyboardType(.numberPad)

            TextField("Description", text: $description, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var referenceSection: some View {
        Section("References") {
            TextField("URL", text: $url)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if sourceType == .book {
                TextField("ISBN", text: $isbn)
                    .textInputAutocapitalization(.never)
            }

            if sourceType == .journalArticle {
                TextField("DOI", text: $doi)
                    .textInputAutocapitalization(.never)
            }
        }
    }

    private var licenseSection: some View {
        Section("License") {
            TextField("License", text: $license)
                .textInputAutocapitalization(.words)

            TextField("License URL", text: $licenseUrl)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func populateForm(from source: Source) {
        sourceType = source.sourceType
        name = source.name
        description = source.description ?? ""
        author = source.author ?? ""
        yearString = source.year.map(String.init) ?? ""
        url = source.url ?? ""
        isbn = source.isbn ?? ""
        doi = source.doi ?? ""
        license = source.license ?? ""
        licenseUrl = source.licenseUrl ?? ""
    }

    private func saveSource() async {
        isSaving = true

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)
        let trimmedAuthor = author.trimmingCharacters(in: .whitespaces)
        let trimmedUrl = url.trimmingCharacters(in: .whitespaces)
        let trimmedIsbn = isbn.trimmingCharacters(in: .whitespaces)
        let trimmedDoi = doi.trimmingCharacters(in: .whitespaces)
        let trimmedLicense = license.trimmingCharacters(in: .whitespaces)
        let trimmedLicenseUrl = licenseUrl.trimmingCharacters(in: .whitespaces)
        let year = Int(yearString)

        if isEditing, let existingSource = source {
            // Update existing source
            let updated = Source(
                id: existingSource.id,
                sourceType: sourceType,
                name: trimmedName,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                author: trimmedAuthor.isEmpty ? nil : trimmedAuthor,
                year: year,
                url: trimmedUrl.isEmpty ? nil : trimmedUrl,
                isbn: trimmedIsbn.isEmpty ? nil : trimmedIsbn,
                doi: trimmedDoi.isEmpty ? nil : trimmedDoi,
                license: trimmedLicense.isEmpty ? nil : trimmedLicense,
                licenseUrl: trimmedLicenseUrl.isEmpty ? nil : trimmedLicenseUrl
            )
            await viewModel.updateSource(updated)
        } else {
            // Create new source
            _ = await viewModel.createSource(
                sourceType: sourceType,
                name: trimmedName,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                author: trimmedAuthor.isEmpty ? nil : trimmedAuthor,
                year: year,
                url: trimmedUrl.isEmpty ? nil : trimmedUrl,
                isbn: trimmedIsbn.isEmpty ? nil : trimmedIsbn,
                doi: trimmedDoi.isEmpty ? nil : trimmedDoi,
                license: trimmedLicense.isEmpty ? nil : trimmedLicense,
                licenseUrl: trimmedLicenseUrl.isEmpty ? nil : trimmedLicenseUrl
            )
        }

        isSaving = false
        dismiss()
    }
}

#Preview("New Source") {
    SourceFormSheet(viewModel: SourcesViewModel(), source: nil)
}

#Preview("Edit Source") {
    SourceFormSheet(
        viewModel: SourcesViewModel(),
        source: Source.samples[0]
    )
}
