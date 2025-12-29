import SwiftUI

@MainActor
struct ContentView: View {
    @State private var notesViewModel = NotesViewModel()
    @State private var sourcesViewModel = SourcesViewModel()

    var body: some View {
        TabView {
            NotesListView(viewModel: notesViewModel)
                .tabItem {
                    Label("Notes", systemImage: "leaf")
                }

            SourcesListView(viewModel: sourcesViewModel)
                .tabItem {
                    Label("Sources", systemImage: "books.vertical")
                }
        }
    }
}

#Preview {
    ContentView()
}
