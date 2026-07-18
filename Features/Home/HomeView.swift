import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Put it in. Draw it out.",
                systemImage: "shippingbox",
                description: Text("Your local activity box will appear here.")
            )
            .navigationTitle("Someday Box")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Image(systemName: "gearshape") } }
        }
    }
}
