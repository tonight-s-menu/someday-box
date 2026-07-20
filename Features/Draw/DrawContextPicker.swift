import SwiftUI

/// Selection-only context sheet. It never starts a draw mutation.
struct DrawContextPicker: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsCustom = false
    @State private var customMinutes = 45

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("How much time do you have?")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("Choose an upper limit. The draw will never quietly go over it.")
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                        ForEach(DrawPresentationPreset.allCases, id: \.self) { preset in
                            let context = DrawContext(preset: preset)
                            Button {
                                choose(context)
                            } label: {
                                VStack(spacing: 3) {
                                    Text(preset.localizedLabel)
                                    Text("Up to \(preset.maximumMinutes) min")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 52)
                            }
                            .buttonStyle(SomedayChoiceButtonStyle(isSelected: appModel.selectedDrawContext == context))
                            .accessibilityIdentifier("draw.context.\(preset.rawValue)")
                        }
                    }

                    Button("Custom time") { showsCustom = true }
                        .buttonStyle(.bordered)
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
                            Button("Use this time") { choose(DrawContext(customMinutes: customMinutes)); showsCustom = false }
                            Button("Not sure") { choose(.notSure); showsCustom = false }
                        }
                    }
                    .navigationTitle("Custom time")
                    .toolbar { Button("Cancel") { showsCustom = false } }
                }
            }
        }
    }

    private func choose(_ context: DrawContext) {
        Task {
            await appModel.updateDrawContext(context)
            dismiss()
        }
    }
}
