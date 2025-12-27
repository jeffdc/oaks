import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            Text("Oak Compendium")
                .font(.largeTitle)
                .navigationTitle("Oak Compendium")
        }
    }
}

#Preview {
    ContentView()
}
