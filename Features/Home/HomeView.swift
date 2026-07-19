import RealityKit
import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @Binding var presentsCapture: Bool
    @Binding var presentsDrawContext: Bool
    @State private var presentsSettings = false
    @State private var presentsPeek = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    CoreBoxStage(
                        inBoxCount: inBoxCount,
                        drawableCount: appModel.drawableCount,
                        memoryCount: appModel.state.memories.count,
                        opensPeek: { presentsPeek = true }
                    )

                    VStack(spacing: 8) {
                        Text("Put it in. Draw it out.")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text(drawableSummary)
                            .foregroundStyle(.primary)
                    }

                    if let current = appModel.currentItem {
                        currentPaper(current)
                    }

                    VStack(spacing: 12) {
                        Button {
                            presentsDrawContext = true
                        } label: {
                            Label("Draw a paper", systemImage: "sparkles")
                                .frame(maxWidth: .infinity, minHeight: 54)
                        }
                        .buttonStyle(SomedayPrimaryActionButtonStyle())
                        .disabled(appModel.drawableCount == 0 || appModel.currentItem != nil)

                        Button {
                            presentsPeek = true
                        } label: {
                            Label("Peek inside", systemImage: "eye")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            presentsCapture = true
                        } label: {
                            Label("Put in an idea", systemImage: "plus")
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: 440)

                    if !recentMemories.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent memories")
                                .font(.headline)
                            ForEach(recentMemories) { memory in
                                HStack(spacing: 12) {
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(SomedayBoxBrand.tint)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(memory.titleSnapshot)
                                        Text(memory.completedAt, format: .dateTime.month().day())
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .frame(maxWidth: 520, alignment: .leading)
                    }
                }
                .padding(24)
            }
            .background(SomedayBoxBrand.canvas)
            .navigationTitle("Someday Box")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { presentsSettings = true }
                }
            }
            .sheet(isPresented: $presentsSettings) { SettingsView() }
            .sheet(isPresented: $presentsPeek) { CoreBoxPeekView() }
            .sensoryFeedback(.success, trigger: appModel.state.memories.count) { oldValue, newValue in
                appModel.hapticsEnabled && newValue > oldValue
            }
        }
    }

    private var drawableSummary: String {
        if appModel.drawableCount == 1 {
            String(localized: "1 paper is ready for a surprise.")
        } else {
            String(localized: "\(appModel.drawableCount) papers are ready for a surprise.")
        }
    }

    private var recentMemories: [CompletionMemory] {
        Array(appModel.state.memories.sorted { $0.completedAt > $1.completedAt }.prefix(2))
    }

    private var inBoxCount: Int {
        let reserved = Set([appModel.currentItem?.id, appModel.unresolvedItem?.id].compactMap { $0 })
        return appModel.state.items.filter { $0.lifecycle == .active && !reserved.contains($0.id) }.count
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

/// A presentation-only scene. Product mutation remains in AppModel use cases.
private struct CoreBoxStage: View {
    let inBoxCount: Int
    let drawableCount: Int
    let memoryCount: Int
    let opensPeek: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            RealityView { content in
                content.camera = .virtual
                content.add(makeScene())
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            Button(action: opensPeek) {
                Text(stageSummary)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Peek inside your Box")
            .accessibilityValue("\(inBoxCount) papers in the Box. \(drawableCount) ready to draw. \(memoryCount) memories.")
        }
        .frame(height: 280)
        .background(SomedayBoxBrand.canvas.opacity(0.7), in: RoundedRectangle(cornerRadius: 32))
        .contentShape(RoundedRectangle(cornerRadius: 32))
        .onTapGesture(perform: opensPeek)
        .accessibilityElement(children: .contain)
    }

    private var stageSummary: String {
        if inBoxCount == 0 { return "Your Box is ready for an idea" }
        return "\(inBoxCount) in the Box · \(drawableCount) ready"
    }

    private func makeScene() -> Entity {
        let root = Entity()
        root.name = "BoxRoot"

        let body = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.30, 0.16, 0.22), cornerRadius: 0.025),
            materials: [SimpleMaterial(color: UIColor(red: 0.62, green: 0.38, blue: 0.23, alpha: 1), roughness: 0.82, isMetallic: false)]
        )
        body.name = "BoxBody"
        body.position = [0, -0.05, 0]
        root.addChild(body)

        let lidPivot = Entity()
        lidPivot.name = "LidPivot"
        lidPivot.position = [0, 0.055, -0.10]
        let lid = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.31, 0.035, 0.23), cornerRadius: 0.025),
            materials: [SimpleMaterial(color: UIColor(red: 0.69, green: 0.44, blue: 0.27, alpha: 1), roughness: 0.8, isMetallic: false)]
        )
        lid.name = "LidMesh"
        lid.position = [0, 0, 0.10]
        lidPivot.addChild(lid)
        root.addChild(lidPivot)

        let ribbon = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.038, 0.006, 0.12), cornerRadius: 0.003),
            materials: [SimpleMaterial(color: UIColor(red: 0.91, green: 0.72, blue: 0.58, alpha: 1), roughness: 0.9, isMetallic: false)]
        )
        ribbon.name = "RibbonRoot"
        ribbon.position = [0, 0.055, 0.16]
        root.addChild(ribbon)

        let paperCount = min(inBoxCount, 10)
        for index in 0..<paperCount {
            let paper = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(0.085, 0.006, 0.055), cornerRadius: 0.002),
                materials: [SimpleMaterial(color: UIColor(white: 0.96, alpha: 1), roughness: 1, isMetallic: false)]
            )
            paper.name = String(format: "PaperRest_%02d", index)
            let x = Float(index % 4 - 1) * 0.045
            let y = 0.04 + Float(index / 4) * 0.009
            let z = Float(index % 3 - 1) * 0.028
            paper.position = SIMD3<Float>(x, y, z)
            paper.orientation = simd_quatf(angle: Float(index) * 0.17, axis: [0, 1, 0])
            root.addChild(paper)
        }

        let keyLight = DirectionalLight()
        keyLight.name = "Light_Key"
        keyLight.light.intensity = 1_200
        keyLight.look(at: .zero, from: [0.4, 0.5, 0.5], relativeTo: nil)
        root.addChild(keyLight)

        let camera = PerspectiveCamera()
        camera.name = "Camera_Default"
        camera.position = [0, 0.20, 0.58]
        camera.look(at: [0, 0.02, 0], from: camera.position, relativeTo: nil)
        root.addChild(camera)
        return root
    }
}

private struct CoreBoxPeekView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    private var inBoxCount: Int {
        let reserved = Set([appModel.currentItem?.id, appModel.unresolvedItem?.id].compactMap { $0 })
        return appModel.state.items.filter { $0.lifecycle == .active && !reserved.contains($0.id) }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(SomedayBoxBrand.box)
                    .accessibilityHidden(true)
                Text("A quiet look inside")
                    .font(.title.bold())
                Text("\(inBoxCount) papers are in your Box. \(appModel.drawableCount) are ready to draw.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text(appModel.state.memories.isEmpty ? "Memories will leave a small seam here when they are ready." : "Your Box carries a small memory seam.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                NavigationLink {
                    BoxView()
                } label: {
                    Label("Organize your Box", systemImage: "square.stack")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding(28)
            .navigationTitle("Peek inside")
            .toolbar { Button("Done") { dismiss() } }
        }
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
