import SwiftUI
import UniformTypeIdentifiers

struct RootTabView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var presentsCapture = false
    @State private var presentsDrawContext = false

    var body: some View {
        Group {
            if appModel.isLoading {
                ProgressView("Opening your Box…")
                    .accessibilityLabel("Opening your Box")
            } else if appModel.loadFailed {
                ContentUnavailableView {
                    Label("Your Box needs attention", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("We couldn't read your local data. Nothing was erased or replaced.")
                } actions: {
                    Button("Try again") { Task { await appModel.load() } }
                        .buttonStyle(.borderedProminent)
                }
            } else if appModel.unresolvedAttempt != nil {
                DrawRevealGate()
            } else if appModel.currentShareRecovery != nil {
                SharedCaptureRecoveryView()
            } else if appModel.requiresProjectionReconciliation {
                ProjectionReconciliationView()
            } else if !appModel.hasSeenIntroduction {
                IntroductionView()
            } else {
                TabView {
                    HomeView(
                        presentsCapture: $presentsCapture,
                        presentsDrawContext: $presentsDrawContext
                    )
                    .tabItem { Label("Home", systemImage: "shippingbox") }
                    BoxView()
                        .tabItem { Label("Box", systemImage: "square.stack") }
                    MemoriesView()
                        .tabItem { Label("Memories", systemImage: "heart.text.square") }
                }
                .sheet(isPresented: $presentsCapture) {
                    CaptureView()
                        .interactiveDismissDisabled(appModel.isMutating)
                }
                .sheet(isPresented: $presentsDrawContext) {
                    DrawContextPicker()
                }
            }
        }
        .task { await appModel.load() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await appModel.refreshSharedCaptures() }
            } else {
                appModel.dropSharedImportPresentation()
            }
        }
        .alert(
            "Your Box was not changed",
            isPresented: Binding(
                get: { appModel.errorMessage != nil && !appModel.loadFailed },
                set: { if !$0 { appModel.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) { appModel.clearError() }
        } message: {
            Text(appModel.errorMessage ?? "")
        }
    }
}

private struct ProjectionReconciliationView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ZStack {
            SomedayBoxBrand.canvas.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 48))
                    .foregroundStyle(SomedayBoxBrand.tint)
                    .accessibilityHidden(true)
                Text("Your Box is saved")
                    .font(.title.bold())
                Text("The latest scene needs to be refreshed before another change can be made.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Refresh scene") {
                    Task { await appModel.retryProjection() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appModel.isMutating)
            }
            .padding(28)
            .frame(maxWidth: 520)
        }
    }
}

private struct SharedCaptureRecoveryView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showsManagement = false
    @State private var confirmsDiscard = false
    @State private var rawDocument: RecoveryFileDocument?
    @State private var exportsRaw = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "shippingbox.and.arrow.backward")
                        .font(.system(size: 48))
                        .foregroundStyle(SomedayBoxBrand.tint)
                        .accessibilityHidden(true)
                    Text(shareFeatureText("Shared capture needs attention"))
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(recoveryDescription)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if appModel.shareRecoveryItems.count > 1 {
                        Text(shareFeatureText("%lld local captures are waiting. Handle this one first.", appModel.shareRecoveryItems.count))
                            .font(.callout)
                    }
                    Button {
                        Task { _ = await appModel.retryCurrentShareRecovery() }
                    } label: {
                        Label(shareFeatureText("Retry"), systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showsManagement = true
                    } label: {
                        Label(shareFeatureText("Manage Box"), systemImage: "square.stack")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)

                    if case .invalid = appModel.currentShareRecovery {
                        Button {
                            guard let data = appModel.currentRawRecoveryData() else { return }
                            rawDocument = RecoveryFileDocument(data: data)
                            exportsRaw = true
                        } label: {
                            Label(shareFeatureText("Export Raw Recovery File"), systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.bordered)
                        Text(shareFeatureText("If this capture came from a newer version, update someday-box before discarding it."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button(shareFeatureText("Discard This Capture"), role: .destructive) { confirmsDiscard = true }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(24)
                .frame(maxWidth: 560)
            }
            .background(SomedayBoxBrand.canvas)
            .navigationTitle(shareFeatureText("Shared Capture Recovery"))
            .sheet(isPresented: $showsManagement) { RecoveryBoxManagementView() }
            .confirmationDialog(shareFeatureText("Discard this local capture?"), isPresented: $confirmsDiscard, titleVisibility: .visible) {
                Button(shareFeatureText("Discard This Capture"), role: .destructive) {
                    Task { _ = await appModel.discardCurrentShareRecovery() }
                }
                Button(shareFeatureText("Cancel"), role: .cancel) {}
            } message: {
                Text(shareFeatureText("This removes only this local capture. Papers and memories already in your Box stay unchanged."))
            }
            .fileExporter(
                isPresented: $exportsRaw,
                document: rawDocument,
                contentType: .data,
                defaultFilename: "someday-box-share-recovery"
            ) { result in
                if case let .failure(error) = result { appModel.report(error) }
                rawDocument = nil
            }
        }
    }

    private var recoveryDescription: String {
        switch appModel.currentShareRecovery {
        case let .pending(entry, message):
            shareFeatureText("“%@” is still stored locally, but it could not be added to the Box yet. %@", entry.envelope.title, message)
        case let .invalid(problem):
            problem.kind == .unsupportedEnvelopeVersion
                ? shareFeatureText("This local capture was written by a newer format. It has not been added to the Box.")
                : shareFeatureText("This local capture could not be validated. It has not been added to the Box.")
        case nil:
            shareFeatureText("The local capture is no longer waiting.")
        }
    }
}

private struct RecoveryBoxManagementView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var backupDocument: RecoveryFileDocument?
    @State private var exportsBackup = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(shareFeatureText("Export a full backup or permanently remove papers to create safe local capacity. Drawing and capture stay unavailable here."))
                        .foregroundStyle(.secondary)
                    Button("Export backup", systemImage: "square.and.arrow.up") {
                        Task {
                            guard let data = await appModel.exportBackupData() else { return }
                            backupDocument = RecoveryFileDocument(data: data)
                            exportsBackup = true
                        }
                    }
                }
                Section(shareFeatureText("Papers")) {
                    ForEach(appModel.state.items.sorted { $0.createdAt > $1.createdAt }) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.title)
                                Text(item.durationLabel).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(shareFeatureText("Delete"), role: .destructive) {
                                Task { _ = await appModel.delete(itemID: item.id) }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .navigationTitle(shareFeatureText("Manage Box"))
            .toolbar { Button(shareFeatureText("Done")) { dismiss() } }
            .fileExporter(
                isPresented: $exportsBackup,
                document: backupDocument,
                contentType: .json,
                defaultFilename: "someday-box-backup"
            ) { result in
                if case let .failure(error) = result { appModel.report(error) }
                backupDocument = nil
            }
        }
    }
}

private struct RecoveryFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data, .json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private struct IntroductionView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ZStack {
            SomedayBoxBrand.canvas.ignoresSafeArea()
            VStack(spacing: 30) {
                Spacer()
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(SomedayBoxBrand.tint)
                    .accessibilityHidden(true)
                VStack(spacing: 12) {
                    Text("someday-box")
                        .font(.largeTitle.bold())
                    Text("Put it in. Draw it out.")
                        .font(.title2.weight(.semibold))
                    Text("Save a possibility without scheduling it. When free time appears, draw one that fits.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Open my Box") { appModel.finishIntroduction() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(minHeight: 44)
                Spacer()
            }
            .padding(28)
            .frame(maxWidth: 560)
        }
    }
}

struct DrawContextView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var selection: DrawContext?
    @State private var showsCustom = false
    @State private var customMinutes = 45

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("How much time do you have?")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("Choose an upper limit. The draw will never quietly go over it.")
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                        ForEach(DrawPresentationPreset.allCases, id: \.self) { preset in
                            let value = DrawContext(preset: preset)
                            let label = preset.localizedLabel
                            let maximum = preset.maximumMinutes
                            Button {
                                selection = value
                            } label: {
                                VStack(spacing: 3) {
                                    Text(label)
                                    Text("Up to \(maximum) min")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(SomedayChoiceButtonStyle(isSelected: selection == value))
                            .accessibilityAddTraits(selection == value ? .isSelected : [])
                        }
                    }

                    Button("Custom time") { showsCustom = true }
                        .buttonStyle(.bordered)
                    if selection == .notSure {
                        Text("Not sure keeps every supported paper available.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        guard let selection else { return }
                        Task {
                            if (await appModel.startDraw(context: selection)).isCommitted { dismiss() }
                        }
                    } label: {
                        Label("Draw a paper", systemImage: "sparkles")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selection == nil || appModel.isMutating)
                }
                .padding(24)
            }
            .background(SomedayBoxBrand.canvas)
            .navigationTitle("Draw")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showsCustom) {
                NavigationStack {
                    Form {
                        Section("Available time") {
                            Stepper("\(customMinutes) minutes", value: $customMinutes, in: 10...480, step: 5)
                        }
                        Section {
                            Button("Use this time") {
                                selection = DrawContext(customMinutes: customMinutes)
                                showsCustom = false
                            }
                            Button("Not sure") {
                                selection = .notSure
                                showsCustom = false
                            }
                        }
                    }
                    .navigationTitle("Custom time")
                    .toolbar { Button("Cancel") { showsCustom = false } }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selection) { oldValue, newValue in
            appModel.hapticsEnabled && oldValue != newValue
        }
    }
}

struct DrawRevealGate: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    private var canRedraw: Bool {
        guard let version = appModel.unresolvedAttempt?.policyVersion else { return false }
        return DrawSelectionPolicy.supportedVersions.contains(version)
    }

    var body: some View {
        ZStack {
            SomedayBoxBrand.canvas.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(SomedayBoxBrand.paperInk)
                    .symbolEffect(.bounce, value: isRevealed)
                    .accessibilityHidden(true)

                if let item = appModel.unresolvedItem {
                    VStack(spacing: 14) {
                        Text(item.title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        if let note = item.note, !note.isEmpty {
                            Text(note)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(item.durationLabel)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(SomedayBoxBrand.tint.opacity(0.13), in: Capsule())
                    }
                    .padding(28)
                    .frame(maxWidth: 520)
                    .background(SomedayBoxBrand.paper, in: RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("draw.reveal.result")
                    .accessibilityLabel(
                        String(
                            format: String(localized: "Drawn paper: %@, %@"),
                            item.title,
                            item.durationLabel
                        )
                    )
                }

                VStack(spacing: 12) {
                    Button {
                        Task { _ = await appModel.acceptDraw() }
                    } label: {
                        Text("Do this")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("draw.accept")

                    Button {
                        Task { _ = await appModel.redraw() }
                    } label: {
                        Text("Draw another")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("draw.redraw")
                    .disabled(!canRedraw || appModel.isMutating)

                    if !canRedraw {
                        Text("This result came from an older draw version. You can still do it or dismiss it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("Dismiss", role: .cancel) {
                        Task { _ = await appModel.dismissDraw() }
                    }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("draw.dismiss")
                }
                .frame(maxWidth: 420)
                .disabled(appModel.isMutating)
                Spacer()
            }
            .padding(24)
        }
        .onAppear {
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.2)) { isRevealed = true }
            } else {
                withAnimation(.spring(duration: 0.65, bounce: 0.18)) { isRevealed = true }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isRevealed) { _, newValue in
            appModel.hapticsEnabled && newValue
        }
    }
}
