import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Binding var presentsCapture: Bool
    @Binding var presentsDrawContext: Bool
    @State private var presentsSettings = false
    @State private var snapshot = BoxSceneStateReducer.reduce(
        BoxSceneInput(state: PersistedProductState(items: []), now: .now)
    )
    @State private var interactionTick = 0
    @State private var isAmbientPaused = false

    var body: some View {
        NavigationStack {
            ZStack {
                EnvironmentRig.backdrop(for: snapshot.light, colorScheme: colorScheme)
                    .ignoresSafeArea()
                BoxSceneView(snapshot: snapshot)
                    .ignoresSafeArea()
                sceneControls
            }
            .navigationTitle("Someday Box")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        noteInteraction()
                        presentsSettings = true
                    }
                }
            }
            .sheet(isPresented: $presentsSettings) { SettingsView() }
            .sensoryFeedback(.success, trigger: appModel.state.memories.count) { oldValue, newValue in
                appModel.hapticsEnabled && newValue > oldValue
            }
        }
        .task { refreshSnapshot() }
        .onChange(of: appModel.state) { _, _ in refreshSnapshot() }
        .onChange(of: appModel.isReplacingProductData) { _, _ in refreshSnapshot() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                noteInteraction()
                refreshSnapshot()
            } else {
                isAmbientPaused = true
            }
        }
        // Ambient quiet: 10 s without interaction pauses the environment, and leaving the
        // foreground pauses it outright (§15.5, PRF-03).
        .task(id: interactionTick) {
            isAmbientPaused = false
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            isAmbientPaused = true
        }
        // The clock rig is the only thing that moves in the B1 stage, so pausing ambience
        // cancels this loop outright rather than letting a timer keep waking the app.
        .task(id: isAmbienceRunning) {
            guard isAmbienceRunning else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                refreshSnapshot()
            }
        }
    }

    private var isAmbienceRunning: Bool {
        !isAmbientPaused && scenePhase == .active
    }

    /// The visible, accessible equivalents that share the scene surface (§3.2). Every
    /// product action reachable through a future 3D gesture is reachable here first.
    private var sceneControls: some View {
        VStack(spacing: 16) {
            Spacer()

            if let current = appModel.currentItem {
                currentPaper(current)
            }

            VStack(spacing: 10) {
                Text(drawableSummary)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Button {
                    noteInteraction()
                    presentsDrawContext = true
                } label: {
                    Label("Draw a paper", systemImage: "sparkles")
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(SomedayPrimaryActionButtonStyle())
                .disabled(isLocked || appModel.drawableCount == 0 || appModel.currentItem != nil)

                Button {
                    noteInteraction()
                    presentsCapture = true
                } label: {
                    Label("Put in an idea", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
                .disabled(isLocked)
            }
            .padding(18)
            // An opaque scrim, not a material: contrast over an animated backdrop has to be
            // guaranteed rather than dependent on what the scene happens to render behind
            // it (AXS-03). The controls keep the exact substrate they are audited on.
            .background {
                // The shadow belongs to the scrim shape alone. Applying it to the panel
                // would also shadow the controls' own text and fills.
                RoundedRectangle(cornerRadius: 24)
                    .fill(SomedayBoxBrand.canvas)
                    .shadow(color: .black.opacity(0.12), radius: 18, y: 6)
            }
            .frame(maxWidth: 440)
        }
        .padding(20)
    }

    /// During an exclusive data operation every scene-initiated mutation affordance is
    /// disabled; this visualises the existing arbiter gate and adds no gating logic (SCN-07).
    private var isLocked: Bool {
        snapshot.gate == .exclusiveDataOperation
    }

    private func noteInteraction() {
        interactionTick &+= 1
    }

    private func refreshSnapshot() {
        snapshot = BoxSceneStateReducer.reduce(
            BoxSceneInput(
                state: appModel.state,
                now: .now,
                timeZone: .current,
                isExclusiveDataOperationInProgress: appModel.isReplacingProductData,
                ambienceFollowsClock: appModel.ambientChangesEnabled
            )
        )
    }

    private var drawableSummary: String {
        if appModel.drawableCount == 1 {
            String(localized: "1 paper is ready for a surprise.")
        } else {
            String(localized: "\(appModel.drawableCount) papers are ready for a surprise.")
        }
    }

    private func currentPaper(_ item: BoxItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your current paper")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(item.title)
                .font(.title3.bold())
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Done") {
                    Task { _ = await appModel.complete(itemID: item.id) }
                }
                .buttonStyle(.borderedProminent)
                Button("Put back") {
                    Task { _ = await appModel.putBack(itemID: item.id) }
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(maxWidth: 520, alignment: .leading)
        .background(SomedayBoxBrand.paper, in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .contain)
    }
}

struct CaptureView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool
    @State private var title = ""
    @State private var note = ""
    @State private var duration: DurationBucket?
    @State private var showsNote = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Paper title", text: $title, axis: .vertical)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .accessibilityLabel("Paper title")
                    Text("Write one small thing you can start in a single free period.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("What just came to mind?")
                }

                Section("How long might it take?") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                        ForEach(DurationBucket.allCases, id: \.self) { value in
                            Button {
                                duration = value
                            } label: {
                                Text(value.localizedLabel)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                            }
                            .buttonStyle(SomedayChoiceButtonStyle(isSelected: duration == value))
                            .accessibilityAddTraits(duration == value ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    if showsNote {
                        TextField("Optional note", text: $note, axis: .vertical)
                            .lineLimit(3...8)
                            .accessibilityLabel("Optional note")
                    } else {
                        Button("Add a note") { showsNote = true }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SomedayBoxBrand.canvas)
            .navigationTitle("Put in an idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Put it in the Box") {
                        guard let duration else { return }
                        Task {
                            if await appModel.capture(
                                title: title,
                                note: showsNote && !note.isEmpty ? note : nil,
                                duration: duration
                            ) { dismiss() }
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || duration == nil || appModel.isMutating)
                }
            }
            .onAppear { titleFocused = true }
        }
    }
}

private struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var exportedDocument: SomedayBoxBackupFile?
    @State private var presentsExporter = false
    @State private var presentsImporter = false
    @State private var pendingRestore: BackupRestorePayload?
    @State private var confirmsRestore = false
    @State private var confirmsErase = false
    @State private var confirmsEraseAgain = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    settingsSectionTitle("Local data")
                    Label {
                        Text("Your papers and memories stay in this app's sandbox. The app has no account, analytics, ads, or product network requests.")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "lock.shield")
                    }
                    Button("Export backup", systemImage: "square.and.arrow.up") {
                        Task {
                            guard let data = await appModel.exportBackupData() else { return }
                            exportedDocument = SomedayBoxBackupFile(data: data)
                            presentsExporter = true
                        }
                    }
                    Button("Restore backup", systemImage: "arrow.counterclockwise") {
                        presentsImporter = true
                    }
                }
                Section {
                    settingsSectionTitle("Experience")
                    Toggle("Haptics", isOn: Binding(
                        get: { appModel.hapticsEnabled },
                        set: { appModel.hapticsEnabled = $0 }
                    ))
                }
                Section {
                    settingsSectionTitle("About")
                    SettingsValueRow(label: "Storage", value: "On this device")
                    SettingsValueRow(label: "Schema", value: "2.0.0")
                    SettingsValueRow(label: "Backup format", value: "2")
                    SettingsValueRow(label: "Draw policy", value: DrawSelectionPolicy.version)
                    SettingsValueRow(label: "Active papers", value: appModel.state.items.filter { $0.lifecycle == .active }.count.formatted())
                    SettingsValueRow(label: "Drawable papers", value: appModel.drawableCount.formatted())
                    SettingsValueRow(label: "Memories", value: appModel.state.memories.count.formatted())
                }
                Section {
                    Button("Erase all local data", role: .destructive) {
                        confirmsErase = true
                    }
                }
            }
            .navigationTitle("Settings")
            .disabled(appModel.isMutating)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.body)
                        .tint(.primary)
                }
            }
            .fileExporter(
                isPresented: $presentsExporter,
                document: exportedDocument,
                contentType: .somedayBoxBackup,
                defaultFilename: "someday-box-backup"
            ) { result in
                if case let .failure(error) = result { appModel.report(error) }
                exportedDocument = nil
            }
            .fileImporter(
                isPresented: $presentsImporter,
                allowedContentTypes: [.somedayBoxBackup, .json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case let .success(urls):
                    guard let url = urls.first else { return }
                    Task { await prepareRestore(from: url) }
                case let .failure(error):
                    appModel.report(error)
                }
            }
            .confirmationDialog(
                "Replace everything in this Box?",
                isPresented: $confirmsRestore,
                titleVisibility: .visible
            ) {
                Button("Replace with this backup", role: .destructive) {
                    guard let pendingRestore else { return }
                    Task {
                        if await appModel.restoreBackup(pendingRestore) {
                            self.pendingRestore = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) { pendingRestore = nil }
            } message: {
                if let pendingRestore {
                    Text("This backup contains \(pendingRestore.state.items.count) papers, \(pendingRestore.state.memories.count) memories, and \(pendingRestore.pendingEnvelopes.count) pending captures. Your current Box will be replaced only after the restored data is verified.")
                }
            }
            .confirmationDialog(
                "Erase all local data?",
                isPresented: $confirmsErase,
                titleVisibility: .visible
            ) {
                Button("Continue", role: .destructive) { confirmsEraseAgain = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Create a backup first if you may want these papers and memories again.")
            }
            .alert("Erase all data permanently?", isPresented: $confirmsEraseAgain) {
                Button("Erase all data", role: .destructive) {
                    Task {
                        if await appModel.eraseAllData() { dismiss() }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The app will switch to a verified empty store, then remove its prior local generations. Exported files and system backups are outside the app's control.")
            }
        }
    }

    private func prepareRestore(from url: URL) async {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try await Task.detached { try BackupFileReader().read(from: url) }.value
            guard let restoredState = await appModel.prepareRestore(data: data) else { return }
            pendingRestore = restoredState
            confirmsRestore = true
        } catch {
            appModel.report(error)
        }
    }

    private func settingsSectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct SettingsValueRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                Spacer(minLength: 16)
                Text(value)
                    .fontWeight(.medium)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                Text(value)
                    .fontWeight(.medium)
            }
        }
        .font(.body)
        .accessibilityElement(children: .combine)
    }
}

private extension UTType {
    static let somedayBoxBackup = UTType(
        exportedAs: "com.somedaybox.backup",
        conformingTo: .json
    )
}

private struct SomedayBoxBackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.somedayBoxBackup, .json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
