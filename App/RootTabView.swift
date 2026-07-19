import SwiftUI

struct RootTabView: View {
    @Environment(AppModel.self) private var appModel
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
                    DrawContextView()
                }
            }
        }
        .task { await appModel.load() }
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
    @State private var selection: AvailableTime?

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
                        ForEach(AvailableTime.allCases, id: \.self) { value in
                            Button {
                                selection = value
                            } label: {
                                Text(value.localizedLabel)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(SomedayChoiceButtonStyle(isSelected: selection == value))
                            .accessibilityAddTraits(selection == value ? .isSelected : [])
                        }
                    }

                    Button {
                        guard let selection else { return }
                        Task {
                            if await appModel.startDraw(availableTime: selection) { dismiss() }
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
                    .scaleEffect(isRevealed ? 1 : 0.94)
                    .opacity(isRevealed ? 1 : 0)
                    .accessibilityElement(children: .combine)
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

                    Button {
                        Task { _ = await appModel.redraw() }
                    } label: {
                        Text("Draw another")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
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
