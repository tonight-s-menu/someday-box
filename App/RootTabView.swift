import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "shippingbox") }
            BoxView()
                .tabItem { Label("Box", systemImage: "square.stack") }
            MemoriesView()
                .tabItem { Label("Memories", systemImage: "heart.text.square") }
        }
    }
}
