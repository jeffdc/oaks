import SwiftUI

@MainActor
struct ContentView: View {
    @State private var viewModel = NotesViewModel()

    var body: some View {
        NotesListView(viewModel: viewModel)
    }
}

#Preview {
    ContentView()
}
