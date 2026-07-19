import SwiftUI

struct MemoriesView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        NavigationStack {
            Group {
                if appModel.state.memories.isEmpty {
                    ContentUnavailableView(
                        "No memories yet",
                        systemImage: "heart.text.square",
                        description: Text("When you do a paper, the moment will be kept here.")
                    )
                } else {
                    List {
                        ForEach(monthGroups, id: \.month) { group in
                            Section(group.month.formatted(.dateTime.month(.wide).year())) {
                                ForEach(group.memories) { memory in
                                    NavigationLink {
                                        MemoryDetailView(memoryID: memory.id)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(memory.titleSnapshot)
                                                .font(.headline)
                                                .fixedSize(horizontal: false, vertical: true)
                                            Text(memory.completedAt, format: .dateTime.month().day().year())
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.vertical, 5)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(SomedayBoxBrand.canvas)
            .navigationTitle("Memories")
        }
    }

    private var monthGroups: [(month: Date, memories: [CompletionMemory])] {
        let calendar = Calendar.autoupdatingCurrent
        let grouped = Dictionary(grouping: appModel.state.memories) { memory in
            let parts = calendar.dateComponents([.year, .month], from: memory.completedAt)
            return calendar.date(from: parts) ?? memory.completedAt
        }
        return grouped.map { month, memories in
            (month, memories.sorted { $0.completedAt > $1.completedAt })
        }
        .sorted { $0.month > $1.month }
    }
}

private struct MemoryDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    let memoryID: UUID
    @State private var confirmsDeletion = false

    private var memory: CompletionMemory? {
        appModel.state.memories.first { $0.id == memoryID }
    }

    var body: some View {
        Group {
            if let memory {
                List {
                    Section {
                        Text(memory.titleSnapshot)
                            .font(.title2.bold())
                            .fixedSize(horizontal: false, vertical: true)
                        if let note = memory.noteSnapshot, !note.isEmpty {
                            Text(note).fixedSize(horizontal: false, vertical: true)
                        }
                        LabeledContent("Completed", value: memory.completedAt.formatted(date: .long, time: .shortened))
                        LabeledContent("Duration", value: memory.durationLabel)
                    }

                    Section("Paper") {
                        memoryAction(memory)
                        Button("Delete paper and its memories", role: .destructive) {
                            confirmsDeletion = true
                        }
                    }
                }
                .navigationTitle("Memory")
                .confirmationDialog(
                    "Delete the source paper permanently?",
                    isPresented: $confirmsDeletion,
                    titleVisibility: .visible
                ) {
                    Button("Delete paper, all its memories, and related draw history", role: .destructive) {
                        Task {
                            if await appModel.delete(itemID: memory.sourceItemID) { dismiss() }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This cannot be undone. Other papers and memories stay unchanged.")
                }
            } else {
                ContentUnavailableView("Memory unavailable", systemImage: "heart.slash")
            }
        }
    }

    @ViewBuilder
    private func memoryAction(_ memory: CompletionMemory) -> some View {
        if let item = appModel.item(id: memory.sourceItemID) {
            if appModel.state.currentPick?.itemID == item.id {
                LabeledContent("Current paper", value: "Already in hand")
            } else {
                switch item.lifecycle {
                case .completed:
                    Button("Put back in the Box") {
                        Task { _ = await appModel.putBack(itemID: item.id) }
                    }
                case .archived:
                    Button("Put back in the Box") {
                        Task { _ = await appModel.restore(itemID: item.id) }
                    }
                case .active:
                    LabeledContent("Already in the Box", value: "No change needed")
                }
            }
        }
    }
}
