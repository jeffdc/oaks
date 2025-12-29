import SwiftUI

/// Full-screen editor for a species note
struct NoteEditorView: View {
    @Binding var note: SpeciesNote
    let source: Source?
    let onSave: (SpeciesNote) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editedNote: SpeciesNote
    @State private var dictationField: NoteField?
    @State private var hasChanges = false

    init(note: Binding<SpeciesNote>, source: Source?, onSave: @escaping (SpeciesNote) -> Void) {
        self._note = note
        self.source = source
        self.onSave = onSave
        self._editedNote = State(initialValue: note.wrappedValue)
    }

    var body: some View {
        Form {
            headerSection

            ForEach(NoteSection.allCases, id: \.self) { section in
                Section(section.displayName) {
                    ForEach(section.fields, id: \.self) { field in
                        FieldEditorRow(
                            field: field,
                            text: binding(for: field),
                            onDictate: {
                                dictationField = field
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle("Edit Note")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveNote()
                }
                .fontWeight(.semibold)
            }
        }
        .sheet(item: $dictationField) { field in
            DictationModal(
                field: field,
                initialText: editedNote.fields[field] ?? "",
                onSave: { text in
                    editedNote.setContent(text, for: field)
                    hasChanges = true
                    dictationField = nil
                },
                onCancel: {
                    dictationField = nil
                }
            )
        }
        .interactiveDismissDisabled(hasChanges)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(editedNote.scientificName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .italic()

                Text(editedNote.taxonomy.displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let source {
                    Label(source.displayName, systemImage: source.iconName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Helpers

    private func binding(for field: NoteField) -> Binding<String> {
        Binding(
            get: { editedNote.fields[field] ?? "" },
            set: { newValue in
                if newValue.isEmpty {
                    editedNote.fields.removeValue(forKey: field)
                } else {
                    editedNote.fields[field] = newValue
                }
                hasChanges = true
            }
        )
    }

    private func saveNote() {
        editedNote.updatedAt = Date()
        note = editedNote
        onSave(editedNote)
        dismiss()
    }
}

// MARK: - Field Editor Row

struct FieldEditorRow: View {
    let field: NoteField
    @Binding var text: String
    let onDictate: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Field header with dictation button
            HStack {
                Label(field.displayName, systemImage: field.iconName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onDictate()
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }

            // Text editor
            TextField(field.placeholder, text: $text, axis: .vertical)
                .lineLimit(3...10)
                .focused($isFocused)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - NoteField Identifiable conformance for sheet

extension NoteField: Identifiable {
    var id: String { rawValue }
}

#Preview {
    NavigationStack {
        NoteEditorView(
            note: .constant(SpeciesNote.sample),
            source: Source.personalObservation,
            onSave: { _ in }
        )
    }
}
