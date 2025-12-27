import SwiftUI

/// Sheet for creating a new species note
struct NewNoteSheet: View {
    @Bindable var viewModel: NotesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var speciesName = ""
    @State private var subgenus = "Quercus"
    @State private var section = "Quercus"
    @State private var isCreating = false

    // Common subgenera for picker
    private let subgenera = ["Quercus", "Lobatae", "Cerris", "Cyclobalanopsis", "Virentes"]

    // Common sections (simplified)
    private let sections = ["Quercus", "Lobatae", "Protobalanus", "Ponticae", "Virentes"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Species") {
                    TextField("Species epithet", text: $speciesName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("Quercus \(speciesName.isEmpty ? "..." : speciesName)")
                        .italic()
                        .foregroundStyle(.secondary)
                }

                Section("Taxonomy") {
                    Picker("Subgenus", selection: $subgenus) {
                        ForEach(subgenera, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }

                    Picker("Section", selection: $section) {
                        ForEach(sections, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                }

                Section {
                    Text("You can add more details after creating the note.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    .disabled(speciesName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
            .interactiveDismissDisabled(isCreating)
        }
    }

    private func createNote() async {
        isCreating = true

        let taxonomy = TaxonomyPath(
            subgenus: subgenus,
            section: section,
            species: speciesName.trimmingCharacters(in: .whitespaces).lowercased()
        )

        if await viewModel.createNote(taxonomy: taxonomy) != nil {
            dismiss()
        }

        isCreating = false
    }
}

#Preview {
    NewNoteSheet(viewModel: NotesViewModel())
}
