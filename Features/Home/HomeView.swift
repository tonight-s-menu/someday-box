import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @Binding var presentsCapture: Bool
    @Binding var presentsDrawContext: Bool
    @State private var presentsSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    boxIllustration

                    VStack(spacing: 8) {
                        Text("Put it in. Draw it out.")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text(drawableSummary)
                            .foregroundStyle(.secondary)
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
                        .buttonStyle(.borderedProminent)
                        .disabled(appModel.drawableCount == 0 || appModel.currentItem != nil)

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
                                            .foregroundStyle(.secondary)
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

    private var boxIllustration: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 28)
                .fill(SomedayBoxBrand.box)
                .frame(width: 210, height: 145)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(.black.opacity(0.14))
                        .frame(width: 106, height: 12)
                        .padding(.top, 24)
                }
            ForEach(0..<min(appModel.drawableCount, 5), id: \.self) { index in
                RoundedRectangle(cornerRadius: 5)
                    .fill(SomedayBoxBrand.paper)
                    .frame(width: 52, height: 34)
                    .rotationEffect(.degrees(Double(index - 2) * 7))
                    .offset(x: CGFloat(index - 2) * 17, y: -CGFloat(index % 2) * 5)
            }
        }
        .padding(.top, 18)
        .accessibilityHidden(true)
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Local data") {
                    Label("Your papers and memories stay in this app's sandbox. The app has no account, analytics, ads, or product network requests.", systemImage: "lock.shield")
                }
                Section("About") {
                    LabeledContent("Storage", value: "On this device")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
