import Observation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
final class ShareViewController: UIViewController {
    private var host: UIHostingController<ShareComposeView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        let model = ShareComposeModel()
        let host = UIHostingController(rootView: ShareComposeView(model: model))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
        self.host = host

        Task { await model.load(context: extensionContext) }
    }
}

@MainActor
@Observable
final class ShareComposeModel {
    enum State: Equatable {
        case receiving
        case ready
        case failed
    }

    var state: State = .receiving
    var title = ""
    var note = ""
    var selectedDuration: DurationBucket?
    var acceptedURLString: String?
    var errorMessage: String?
    var showsNote = false

    func load(context: NSExtensionContext?) async {
        guard let item = context?.inputItems.compactMap({ $0 as? NSExtensionItem }).only else {
            fail(shareText("Share one link or piece of text at a time."))
            return
        }

        let payload = await SharedPayloadLoader().load(item: item)
        do {
            let candidate = try SharePayloadExtractor().extract(from: payload)
            acceptedURLString = candidate.acceptedURLString
            title = candidate.titleCandidate ?? ""
            state = .ready
        } catch SharePayloadValidationFailure.textTooLarge {
            fail(shareText("This shared text is too long to add safely."))
        } catch {
            fail(shareText("This content could not be read. Try sharing one link or piece of text."))
        }
    }

    func removeLink() {
        acceptedURLString = nil
    }

    private func fail(_ message: String) {
        errorMessage = message
        state = .failed
    }
}

private struct ShareComposeView: View {
    @Bindable var model: ShareComposeModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch model.state {
                    case .receiving:
                        ProgressView(shareText("Reading shared content…"))
                            .frame(maxWidth: .infinity, minHeight: 180)
                    case .failed:
                        ContentUnavailableView(
                            shareText("Can’t add this yet"),
                            systemImage: "exclamationmark.triangle",
                            description: Text(model.errorMessage ?? shareText("This content could not be read."))
                        )
                    case .ready:
                        composeFields
                    }
                }
                .padding(20)
            }
            .navigationTitle(shareText("Add to someday-box"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var composeFields: some View {
        Group {
            TextField(shareText("Title"), text: $model.title, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(shareText("Title"))

            VStack(alignment: .leading, spacing: 8) {
                Text(shareText("Source")).font(.headline)
                if let source = model.acceptedURLString, let host = URL(string: source)?.host {
                    HStack {
                        Label(shareText("Link from %@", host), systemImage: "link")
                            .lineLimit(1)
                        Spacer()
                        Button(shareText("Remove link")) { model.removeLink() }
                    }
                } else {
                    Text(shareText("No link will be saved"))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(shareText("How long might it take?")).font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 78))], spacing: 10) {
                    ForEach(DurationBucket.allCases, id: \.self) { duration in
                        Button(duration.shareLabel) { model.selectedDuration = duration }
                            .buttonStyle(.bordered)
                            .tint(model.selectedDuration == duration ? .accentColor : .secondary)
                            .accessibilityAddTraits(model.selectedDuration == duration ? .isSelected : [])
                    }
                }
            }

            DisclosureGroup(shareText("Add a note"), isExpanded: $model.showsNote) {
                TextField(shareText("Note"), text: $model.note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }

            Text(shareText("Saving shares will be enabled after the local mailbox safety milestone."))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(shareText("Save for the Box")) {}
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, minHeight: 48)
                .disabled(true)
                .accessibilityHint(shareText("Not available in this development build."))
        }
    }
}

@MainActor
private struct SharedPayloadLoader {
    func load(item: NSExtensionItem) async -> SharedPayload {
        let providers = item.attachments ?? []
        let url = await firstURL(from: providers)
        let text = await firstText(from: providers)
        return SharedPayload(
            explicitURLString: url,
            plainText: text,
            attributedTitle: item.attributedTitle?.string
        )
    }

    private func firstURL(from providers: [NSItemProvider]) async -> String? {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let value = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil),
               let url = value as? URL {
                return url.absoluteString
            }
        }
        return nil
    }

    private func firstText(from providers: [NSItemProvider]) async -> String? {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let value = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) {
                if let text = value as? String { return text }
                if let text = value as? NSAttributedString { return text.string }
            }
        }
        return nil
    }
}

private extension Array {
    var only: Element? { count == 1 ? first : nil }
}

private extension DurationBucket {
    var shareLabel: String {
        switch self {
        case .upTo10Minutes: "10m"
        case .upTo30Minutes: "30m"
        case .upTo60Minutes: "1h"
        case .upTo120Minutes: "2h"
        case .upTo240Minutes: "4h"
        case .upTo480Minutes: "8h"
        }
    }
}

private func shareText(_ english: String, _ argument: CVarArg? = nil) -> String {
    let simplifiedChinese: [String: String] = [
        "Share one link or piece of text at a time.": "请一次只分享一个链接或一段文字。",
        "This shared text is too long to add safely.": "这段分享文字太长，无法安全放入。",
        "This content could not be read. Try sharing one link or piece of text.": "无法读取这项内容。请尝试分享一个链接或一段文字。",
        "Reading shared content…": "正在读取分享内容…",
        "Can’t add this yet": "暂时无法放入",
        "This content could not be read.": "无法读取这项内容。",
        "Add to someday-box": "放进改天盲盒",
        "Title": "标题",
        "Source": "来源",
        "Link from %@": "链接来自 %@",
        "Remove link": "移除链接",
        "No link will be saved": "不会保存链接",
        "How long might it take?": "大概需要多久？",
        "Add a note": "添加备注",
        "Note": "备注",
        "Saving shares will be enabled after the local mailbox safety milestone.": "本地邮箱安全里程碑完成后，才会开放保存分享。",
        "Save for the Box": "先替我收好",
        "Not available in this development build.": "此开发版本暂不可用。",
    ]
    let isChinese = Locale.current.language.languageCode?.identifier == "zh"
    let format = isChinese ? (simplifiedChinese[english] ?? english) : english
    guard let argument else { return format }
    return String(format: format, locale: Locale.current, arguments: [argument])
}
