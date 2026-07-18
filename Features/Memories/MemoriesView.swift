import SwiftUI

struct MemoriesView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("No memories yet", systemImage: "heart.text.square")
                .navigationTitle("Memories")
        }
    }
}
