import SwiftUI

struct BoxView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Your Box is empty", systemImage: "square.stack")
                .navigationTitle("Box")
        }
    }
}
