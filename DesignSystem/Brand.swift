import SwiftUI

enum SomedayBoxBrand {
    static let tint = Color(red: 0.73, green: 0.30, blue: 0.16)
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
