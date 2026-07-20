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
                        snapshot: presentationSnapshot,
                        event: appModel.latestPresentationEvent,
                        ribbonArmed: appModel.selectedDrawContext != nil && appModel.drawAvailability.selectedContextEligibleCount > 0,
                        pullsRibbon: requestDraw,
                        opensPeek: { presentsPeek = true },
                        requestEffectiveTier: { tier, reason in
                            Task { await appModel.requestEffectiveRendererTier(tier, reason: reason) }
                        }
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
                            requestDraw()
                        } label: {
                            Label("Draw a paper", systemImage: "sparkles")
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(SomedayPrimaryActionButtonStyle())
                        .accessibilityIdentifier("home.draw")
                        .disabled(!drawEnabled)

                        Button {
                            presentsPeek = true
                        } label: {
                            Label("Peek inside", systemImage: "eye")
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(.bordered)
                        .tint(.primary)
                        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityIdentifier("home.peek")

                        Button {
                            presentsCapture = true
                        } label: {
                            Label("Put in an idea", systemImage: "plus")
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(SomedayPrimaryActionButtonStyle())
                        .accessibilityIdentifier("home.capture")
                    }
                    .frame(maxWidth: 440)

                }
                .padding(24)
                .safeAreaPadding(.bottom, 120)
            }
            .background(SomedayBoxBrand.canvas)
            .navigationTitle("Someday Box")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { presentsSettings = true }
                        .accessibilityIdentifier("home.settings")
                }
            }
            .sheet(isPresented: $presentsSettings) { SettingsView() }
            .sheet(isPresented: $presentsPeek) { CoreBoxPeekView() }
            .sensoryFeedback(.success, trigger: appModel.state.memories.count) { oldValue, newValue in
                appModel.hapticsEnabled && newValue > oldValue
            }
            .overlay(alignment: .top) {
                if let batch = appModel.sharedImportPresentation, batch.expiresAt > Date() {
                    Label(
                        batch.count == 1 ? "A shared paper arrived" : "\(batch.count) shared papers arrived",
                        systemImage: "shippingbox.and.arrow.backward.fill"
                    )
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .accessibilityAddTraits(.isStaticText)
                    .onTapGesture { appModel.dropSharedImportPresentation() }
                }
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

    private var presentationSnapshot: CoreBoxSceneSnapshot {
        appModel.sceneSnapshot ?? CoreBoxSceneSnapshot(
            inBoxCount: inBoxCount,
            drawableCount: appModel.drawableCount,
            memoryCount: appModel.state.memories.count,
            hasCurrentPick: appModel.currentItem != nil,
            papers: [],
            rendererTier: appModel.presentationPreferences.renderer.maximumTier,
            motionMode: appModel.presentationPreferences.quickAnimations ? .quick : .normal,
            snapshotVersion: appModel.snapshotVersion
        )
    }

    private var drawEnabled: Bool {
        appModel.selectedDrawContext != nil
            && appModel.drawAvailability.selectedContextEligibleCount > 0
            && !appModel.requiresProjectionReconciliation
            && !appModel.isMutating
            && appModel.unresolvedAttempt == nil
            && appModel.currentItem == nil
    }

    private func requestDraw() {
        guard let context = appModel.selectedDrawContext else {
            presentsDrawContext = true
            return
        }
        guard drawEnabled else { return }
        Task { _ = await appModel.startDraw(context: context) }
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
                .accessibilityIdentifier("home.current.complete")
                Button("Put back") {
                    Task { _ = await appModel.putBack(itemID: item.id) }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("home.current.putBack")
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(maxWidth: 520, alignment: .leading)
        .background(SomedayBoxBrand.paper, in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.current")
    }
}

/// A presentation-only scene. Product mutation remains in AppModel use cases;
/// RealityKit is entered only through the validated asset loader.
private struct CoreBoxStage: View {
    let snapshot: CoreBoxSceneSnapshot
    let event: CoreBoxCorrelatedEvent?
    let ribbonArmed: Bool
    let pullsRibbon: () -> Void
    let opensPeek: () -> Void
    let requestEffectiveTier: @MainActor (CoreBoxRendererTier, CoreBoxFallbackReason) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var adapter: CoreBox2DAdapter
    @State private var controller: CoreBoxStageController
    @State private var pullProgress = 0.0
    @State private var submittedPull = false

    init(
        snapshot: CoreBoxSceneSnapshot,
        event: CoreBoxCorrelatedEvent?,
        ribbonArmed: Bool,
        pullsRibbon: @escaping () -> Void,
        opensPeek: @escaping () -> Void,
        requestEffectiveTier: @escaping @MainActor (CoreBoxRendererTier, CoreBoxFallbackReason) -> Void
    ) {
        self.snapshot = snapshot
        self.event = event
        self.ribbonArmed = ribbonArmed
        self.pullsRibbon = pullsRibbon
        self.opensPeek = opensPeek
        self.requestEffectiveTier = requestEffectiveTier
        let adapter = CoreBox2DAdapter()
        _adapter = State(initialValue: adapter)
        _controller = State(initialValue: CoreBoxStageController(
            loader: .application,
            adapter: adapter,
            requestEffectiveTier: requestEffectiveTier
        ))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if snapshot.rendererTier == .swiftUI2D || controller.isAwaitingTierProjection {
                    CoreBox2DStage(snapshot: snapshot)
                } else {
                    CoreBoxRealityStage(snapshot: snapshot, event: event, controller: controller)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            Button(action: opensPeek) {
                Text(stageSummary)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.box.summary")
            .accessibilityLabel("Peek inside your Box")
            .accessibilityValue("\(snapshot.inBoxCount) papers in the Box. \(snapshot.drawAvailability.totalSupportedCount) ready to draw. \(snapshot.memoryCount) memories.")

            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Capsule()
                        .fill(SomedayBoxBrand.tint)
                        .frame(width: 16, height: 54 + pullProgress * 34)
                    Text("Pull to draw")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 88, height: 98, alignment: .top)
                .contentShape(Rectangle())
                .gesture(ribbonGesture)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("home.ribbon")
                .accessibilityLabel("Pull to draw")
                .accessibilityValue(ribbonArmed ? "Armed" : "Not armed")
                .accessibilityHint(ribbonArmed ? "Pull down to draw." : "Choose a time before pulling.")
                .accessibilityAction { pullsRibbon() }
            }
            .padding(.trailing, 14)
            .padding(.bottom, 36)
        }
        .frame(height: 220)
        .background(SomedayBoxBrand.canvas.opacity(0.7), in: RoundedRectangle(cornerRadius: 32))
        .contentShape(RoundedRectangle(cornerRadius: 32))
        .onTapGesture(perform: opensPeek)
        .onChange(of: scenePhase) { _, value in
            if value != .active { controller.teardown() }
        }
        .onChange(of: snapshot.snapshotVersion) { _, _ in
            controller.update(snapshot: snapshot, event: event)
        }
        .onChange(of: event?.sequence) { _, _ in
            controller.update(snapshot: snapshot, event: event)
        }
        .task {
            controller.update(snapshot: snapshot, event: event)
        }
        .accessibilityElement(children: .contain)
    }

    private var stageSummary: String {
        if snapshot.inBoxCount == 0 { return "Your Box is ready for an idea" }
        return "\(snapshot.inBoxCount) in the Box · \(snapshot.drawAvailability.totalSupportedCount) ready"
    }

    private var ribbonGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !submittedPull else { return }
                pullProgress = min(max(value.translation.height / 80, 0), 1)
            }
            .onEnded { _ in
                let committed = pullProgress >= 0.72 && !submittedPull
                submittedPull = committed
                if committed { pullsRibbon() }
                withAnimation(reduceMotion ? nil : .snappy(duration: snapshot.motionMode == .quick ? 0.12 : 0.22)) {
                    pullProgress = 0
                }
                submittedPull = false
            }
    }

    private var inBoxCount: Int { snapshot.inBoxCount }
}

private struct CoreBox2DStage: View {
    let snapshot: CoreBoxSceneSnapshot

    var body: some View {
        ZStack {
            Ellipse()
                .fill(.black.opacity(0.12))
                .frame(width: 230, height: 32)
                .offset(y: 88)
            RoundedRectangle(cornerRadius: 24)
                .fill(SomedayBoxBrand.box)
                .frame(width: 230, height: 132)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(SomedayBoxBrand.box.opacity(0.82))
                        .frame(height: 34)
                }
            Capsule()
                .fill(SomedayBoxBrand.paper)
                .frame(width: 34, height: 106)
                .rotationEffect(.degrees(-8))
                .offset(x: 86, y: 12)
            if snapshot.inBoxCount > 0 {
                ForEach(0..<min(snapshot.inBoxCount, 6), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(SomedayBoxBrand.paper)
                        .frame(width: 56, height: 22)
                        .rotationEffect(.degrees(Double(index - 2) * 4))
                        .offset(x: CGFloat((index % 3) - 1) * 32, y: -42 + CGFloat(index / 3) * 10)
                }
            }
            if snapshot.memoryCount > 0 {
                Capsule()
                    .fill(SomedayBoxBrand.paperInk.opacity(0.55))
                    .frame(width: 116, height: 3)
                    .offset(y: 48)
            }
        }
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
                        .accessibilityIdentifier("capture.title")
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
                            .accessibilityIdentifier("capture.duration.\(value.rawValue)")
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
                        .accessibilityIdentifier("capture.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Put it in the Box") {
                        guard let duration else { return }
                        Task {
                            if await appModel.capture(
                                title: title,
                                note: showsNote && !note.isEmpty ? note : nil,
                                duration: duration
                            ).isCommitted { dismiss() }
                        }
                    }
                    .accessibilityIdentifier("capture.save")
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
                    Picker("Box renderer", selection: Binding(
                        get: { appModel.presentationPreferences.renderer },
                        set: { value in Task { await appModel.requestRendererPreference(value) } }
                    )) {
                        Text("Automatic").tag(CoreBoxRendererPreference.automatic)
                            .accessibilityIdentifier("renderer.automatic")
                        Text("Full 3D").tag(CoreBoxRendererPreference.full3D)
                            .accessibilityIdentifier("renderer.full3D")
                        Text("Simplified 2D").tag(CoreBoxRendererPreference.simplified2D)
                            .accessibilityIdentifier("renderer.simplified2D")
                    }
                    .accessibilityIdentifier("renderer.preference.control")
                    Toggle("Quick animations", isOn: Binding(
                        get: { appModel.presentationPreferences.quickAnimations },
                        set: { appModel.presentationPreferences.quickAnimations = $0 }
                    ))
                    Toggle("Sound", isOn: Binding(
                        get: { appModel.presentationPreferences.soundEnabled },
                        set: { appModel.presentationPreferences.soundEnabled = $0 }
                    ))
                    Toggle("Haptics", isOn: Binding(
                        get: { appModel.hapticsEnabled },
                        set: { appModel.hapticsEnabled = $0 }
                    ))
                    Toggle("Quiet ambience", isOn: Binding(
                        get: { appModel.presentationPreferences.ambienceEnabled },
                        set: { appModel.presentationPreferences.ambienceEnabled = $0 }
                    ))
                }
                Section {
                    settingsSectionTitle("About")
                    SettingsValueRow(label: "Storage", value: "On this device")
                    SettingsValueRow(label: "Schema", value: "3.0.0")
                    SettingsValueRow(label: "Backup format", value: "3")
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
