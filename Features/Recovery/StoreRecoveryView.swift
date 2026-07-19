import SwiftUI
import UniformTypeIdentifiers

struct StoreRecoveryView: View {
    let service: StoreRecoveryService
    let onRecovered: () -> Void

    @State private var importsBackup = false
    @State private var confirmsErase = false
    @State private var confirmsEraseAgain = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .font(.system(size: 52))
                        .foregroundStyle(SomedayBoxBrand.tint)
                        .accessibilityHidden(true)
                    Text("Your Box needs Recovery")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("The selected local store could not be opened. It has not been replaced or described as empty.")
                        .foregroundStyle(.secondary)
                    Button("Try opening again", systemImage: "arrow.clockwise", action: onRecovered)
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 48)
                    Button("Recover from backup", systemImage: "doc.badge.arrow.up") { importsBackup = true }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 48)
                    Text("Recovery validates a separate generation before switching to it. The unreadable generation is retained.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Divider()
                    Button("Erase all local data", role: .destructive) { confirmsErase = true }
                        .frame(minHeight: 44)
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).accessibilityLabel("Recovery error: \(errorMessage)")
                    }
                }
                .padding(28)
                .frame(maxWidth: 560, alignment: .leading)
            }
            .navigationTitle("Store Recovery")
            .disabled(isWorking)
            .fileImporter(isPresented: $importsBackup, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                guard case let .success(urls) = result, let url = urls.first else { return }
                Task { await recover(url) }
            }
            .confirmationDialog("Erase every app-owned local generation?", isPresented: $confirmsErase, titleVisibility: .visible) {
                Button("Continue", role: .destructive) { confirmsEraseAgain = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Use backup recovery first if you may want these papers again.")
            }
            .alert("Erase all data permanently?", isPresented: $confirmsEraseAgain) {
                Button("Erase all data", role: .destructive) { Task { await erase() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deliberately creates and validates an empty local generation, selects it, and removes prior app-owned generations.")
            }
        }
    }

    private func recover(_ url: URL) async {
        isWorking = true
        defer { isWorking = false }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try BackupFileReader().read(from: url)
            try await service.recover(from: data)
            onRecovered()
        } catch {
            errorMessage = String(localized: "This backup could not be validated. The selected store was kept.")
        }
    }

    private func erase() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await service.eraseAllAfterExplicitConfirmation()
            onRecovered()
        } catch {
            errorMessage = String(localized: "Recovery could not finish. Existing local generations were kept where possible.")
        }
    }
}
