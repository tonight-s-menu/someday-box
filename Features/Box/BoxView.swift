import SwiftUI

struct BoxView: View {
    @Environment(AppModel.self) private var appModel
    @State private var searchText = ""
    @State private var scope = BoxScope.inBox
    @State private var duration: DurationBucket?

    var body: some View {
        NavigationStack {
            Group {
                if filteredItems.isEmpty {
                    ContentUnavailableView {
                        Label(emptyTitle, systemImage: searchText.isEmpty ? "square.stack" : "magnifyingglass")
                    } description: {
                        Text(emptyDescription)
                    }
                } else {
                    List(filteredItems) { item in
                        NavigationLink {
                            PaperDetailView(itemID: item.id)
                        } label: {
                            PaperRow(item: item, isCurrent: appModel.state.currentPick?.itemID == item.id)
                        }
                        .accessibilityHint("Opens paper details")
                    }
                    .listStyle(.plain)
                }
            }
            .background(SomedayBoxBrand.canvas)
            .navigationTitle("Box")
            .searchable(text: $searchText, prompt: "Search title and note")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Paper status", selection: $scope) {
                            ForEach(BoxScope.allCases) { value in
                                Text(value.label).tag(value)
                            }
                        }
                    } label: {
                        Label("Paper status", systemImage: "tray.full")
                    }
                    Menu {
                        Button("All durations") { duration = nil }
                        ForEach(DurationBucket.allCases, id: \.self) { value in
                            Button(value.localizedLabel) { duration = value }
                        }
                    } label: {
                        Label("Duration filter", systemImage: duration == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
        }
    }

    private var filteredItems: [BoxItem] {
        let reservedID = appModel.unresolvedAttempt?.itemID
        let currentID = appModel.state.currentPick?.itemID
        return appModel.state.items.filter { item in
            let matchesScope: Bool
            switch scope {
            case .inBox:
                matchesScope = item.lifecycle == .active && item.id != currentID && item.id != reservedID
            case .current:
                matchesScope = item.id == currentID
            case .archived:
                matchesScope = item.lifecycle == .archived
            }
            let matchesDuration = duration == nil || item.supportedDuration == duration
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || item.title.localizedCaseInsensitiveContains(query)
                || item.note?.localizedCaseInsensitiveContains(query) == true
            return matchesScope && matchesDuration && matchesSearch
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    private var emptyTitle: LocalizedStringKey {
        searchText.isEmpty ? "No papers here" : "No matching papers"
    }

    private var emptyDescription: LocalizedStringKey {
        searchText.isEmpty
            ? "Ideas you put in the Box will appear here."
            : "Try a different word or filter."
    }
}

private enum BoxScope: String, CaseIterable, Identifiable {
    case inBox
    case current
    case archived

    var id: Self { self }

    var label: LocalizedStringKey {
        switch self {
        case .inBox: "In the Box"
        case .current: "Current paper"
        case .archived: "Archived"
        }
    }
}

private struct PaperRow: View {
    let item: BoxItem
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(SomedayBoxBrand.paper)
                .frame(width: 38, height: 48)
                .overlay(Image(systemName: "doc.text").foregroundStyle(SomedayBoxBrand.paperInk))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text(item.durationLabel)
                    if isCurrent { Text("Current paper") }
                }
                .font(.caption)
                .foregroundStyle(item.supportedDuration == nil ? Color.orange : .secondary)
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

private struct PaperDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    let itemID: UUID
    @State private var isEditing = false
    @State private var title = ""
    @State private var note = ""
    @State private var duration = DurationBucket.upTo30Minutes
    @State private var confirmsDeletion = false

    var body: some View {
        Group {
            if let item = appModel.item(id: itemID) {
                Form {
                    if isEditing {
                        Section("Paper") {
                            TextField("Paper title", text: $title, axis: .vertical)
                            TextField("Optional note", text: $note, axis: .vertical)
                            Picker("Duration", selection: $duration) {
                                ForEach(DurationBucket.allCases, id: \.self) { value in
                                    Text(value.localizedLabel).tag(value)
                                }
                            }
                        }
                    } else {
                        Section {
                            Text(item.title)
                                .font(.title2.bold())
                                .fixedSize(horizontal: false, vertical: true)
                            if let note = item.note, !note.isEmpty {
                                Text(note).fixedSize(horizontal: false, vertical: true)
                            }
                            LabeledContent("Duration", value: item.durationLabel)
                        }
                    }

                    Section("Actions") {
                        if appModel.state.currentPick?.itemID == item.id {
                            Button("Done") { Task { await complete(item.id) } }
                            Button("Put back") { Task { await putBack(item.id) } }
                            Button("Archive") { Task { await archive(item.id) } }
                        } else {
                            switch item.lifecycle {
                            case .active:
                                Button("Mark as done") { Task { await complete(item.id) } }
                                Button("Archive") { Task { await archive(item.id) } }
                            case .archived:
                                Button("Restore to the Box") { Task { _ = await appModel.restore(itemID: item.id) } }
                            case .completed:
                                Button("Put back in the Box") { Task { _ = await appModel.putBack(itemID: item.id) } }
                            }
                        }
                        Button("Delete permanently", role: .destructive) { confirmsDeletion = true }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(SomedayBoxBrand.canvas)
                .navigationTitle("Paper")
                .toolbar {
                    if item.lifecycle == .active || item.lifecycle == .archived {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(isEditing ? "Save" : "Edit") {
                                if isEditing {
                                    Task {
                                        if await appModel.edit(itemID: item.id, title: title, note: note.isEmpty ? nil : note, duration: duration) {
                                            isEditing = false
                                        }
                                    }
                                } else {
                                    title = item.title
                                    note = item.note ?? ""
                                    duration = item.supportedDuration ?? .upTo30Minutes
                                    isEditing = true
                                }
                            }
                            .disabled(isEditing && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .confirmationDialog(
                    "Delete this paper permanently?",
                    isPresented: $confirmsDeletion,
                    titleVisibility: .visible
                ) {
                    Button("Delete paper, its memories, and related draw history", role: .destructive) {
                        Task {
                            if await appModel.delete(itemID: item.id) { dismiss() }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This cannot be undone. Other papers and memories stay unchanged.")
                }
            } else {
                ContentUnavailableView("Paper unavailable", systemImage: "doc.questionmark")
            }
        }
    }

    private func complete(_ id: UUID) async {
        if await appModel.complete(itemID: id) { dismiss() }
    }

    private func putBack(_ id: UUID) async {
        if await appModel.putBack(itemID: id) { dismiss() }
    }

    private func archive(_ id: UUID) async {
        if await appModel.archive(itemID: id) { dismiss() }
    }
}
