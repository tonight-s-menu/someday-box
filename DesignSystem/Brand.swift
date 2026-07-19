import SwiftUI

func shareFeatureText(_ english: String, _ arguments: CVarArg...) -> String {
    let simplifiedChinese: [String: String] = [
        "Source": "来源",
        "Shared link": "分享链接",
        "Open Original": "打开原链接",
        "Copy or share link": "复制或分享链接",
        "Shared content": "分享内容",
        "Text only": "仅文字",
        "Captured": "收取时间",
        "Remove Source": "移除来源",
        "Remove this source?": "移除这个来源？",
        "Cancel": "取消",
        "The paper stays in your Box. The saved link and share provenance will be removed.": "纸条会留在盲盒中，但保存的链接和分享来源会被移除。",
        "Shared capture needs attention": "一份分享收件需要处理",
        "%lld local captures are waiting. Handle this one first.": "有 %lld 份本地收件在等待，请先处理这一份。",
        "Retry": "重试",
        "Manage Box": "管理盲盒",
        "Export Raw Recovery File": "导出原始恢复文件",
        "If this capture came from a newer version, update someday-box before discarding it.": "如果这份收件来自更新版本，请先更新改天盲盒再丢弃。",
        "Discard This Capture": "丢弃这份收件",
        "Shared Capture Recovery": "分享收件恢复",
        "Discard this local capture?": "丢弃这份本地收件？",
        "This removes only this local capture. Papers and memories already in your Box stay unchanged.": "这只会移除当前本地收件，盲盒中已有的纸条和回忆不会改变。",
        "Export a full backup or permanently remove papers to create safe local capacity. Drawing and capture stay unavailable here.": "可导出完整备份，或永久移除纸条以安全腾出本地空间。这里不会开放抽取或收取。",
        "Papers": "纸条",
        "Delete": "删除",
        "Done": "完成",
        "“%@” is still stored locally, but it could not be added to the Box yet. %@": "“%@”仍安全保存在本地，但暂时无法放入盲盒。%@",
        "This local capture was written by a newer format. It has not been added to the Box.": "这份本地收件由更新格式写入，尚未放入盲盒。",
        "This local capture could not be validated. It has not been added to the Box.": "无法安全验证这份本地收件，因此尚未放入盲盒。",
        "The local capture is no longer waiting.": "这份本地收件已不再等待处理。",
        "This capture cannot be read safely. Export or discard it, or update someday-box if it came from a newer version.": "无法安全读取这份收件。请导出或丢弃；若它来自更新格式，请先更新改天盲盒。",
        "A shared capture needs attention. Its local bytes were kept.": "一份分享收件需要处理，其本地原始内容已保留。",
        "Shared captures are using the available local mailbox space. Export or remove content, then try again.": "分享收件已占满可用的本地邮箱空间，请先导出或移除内容再重试。",
    ]
    let isChinese = Locale.current.language.languageCode?.identifier == "zh"
    let format = isChinese ? (simplifiedChinese[english] ?? english) : english
    return arguments.isEmpty ? format : String(format: format, locale: Locale.current, arguments: arguments)
}

enum SomedayBoxBrand {
    static let tint = Color(red: 0.58, green: 0.18, blue: 0.06)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let paper = Color(uiColor: .secondarySystemGroupedBackground)
    static let box = Color(red: 0.72, green: 0.44, blue: 0.25)
    static let paperInk = Color(red: 0.42, green: 0.24, blue: 0.15)
}

struct SomedayChoiceButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : SomedayBoxBrand.tint)
            .padding(.horizontal, 12)
            .background(
                isSelected ? SomedayBoxBrand.tint : SomedayBoxBrand.paper,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(SomedayBoxBrand.tint.opacity(isSelected ? 0 : 0.32), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
            .contentShape(Rectangle())
    }
}

struct SomedayPrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? Color.white : Color.primary)
            .padding(.horizontal, 16)
            .background(
                isEnabled ? SomedayBoxBrand.tint : Color(uiColor: .tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
            .contentShape(Rectangle())
    }
}

extension DurationBucket {
    var localizedLabel: String {
        switch self {
        case .upTo10Minutes: String(localized: "Up to 10 minutes")
        case .upTo30Minutes: String(localized: "Up to 30 minutes")
        case .upTo60Minutes: String(localized: "Up to 1 hour")
        case .upTo120Minutes: String(localized: "Up to 2 hours")
        case .upTo240Minutes: String(localized: "Up to 4 hours")
        case .upTo480Minutes: String(localized: "Up to 8 hours")
        }
    }
}

extension AvailableTime {
    var localizedLabel: String {
        guard let duration = DurationBucket(rawValue: rawValue) else {
            return String(localized: "Not sure")
        }
        return duration.localizedLabel
    }
}

extension DrawPresentationPreset {
    var localizedLabel: String {
        switch self {
        case .fewMinutes: String(localized: "A few minutes")
        case .aboutAnHour: String(localized: "About an hour")
        case .aFewHours: String(localized: "A few hours")
        case .mostOfTheDay: String(localized: "Most of the day")
        }
    }
}

extension BoxItem {
    var durationLabel: String {
        supportedDuration?.localizedLabel ?? String(localized: "Duration needs updating")
    }
}

extension CompletionMemory {
    var durationLabel: String {
        DurationBucket(rawValue: durationSnapshotRaw)?.localizedLabel
            ?? String(localized: "Previous duration unavailable")
    }
}
