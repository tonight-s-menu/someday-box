import Foundation

/// A bounded representation of values deliberately supplied to the Share Extension.
/// It contains no host identity, attachment, or network-derived metadata.
public struct SharedPayload: Equatable, Sendable {
    public let explicitURLString: String?
    public let plainText: String?
    public let attributedTitle: String?

    public init(explicitURLString: String? = nil, plainText: String? = nil, attributedTitle: String? = nil) {
        self.explicitURLString = explicitURLString
        self.plainText = plainText
        self.attributedTitle = attributedTitle
    }
}

public struct ShareDraftCandidate: Equatable, Sendable {
    public let acceptedURLString: String?
    public let titleCandidate: String?
    public let plainText: String?

    public init(acceptedURLString: String?, titleCandidate: String?, plainText: String?) {
        self.acceptedURLString = acceptedURLString
        self.titleCandidate = titleCandidate
        self.plainText = plainText
    }
}

public enum SharePayloadValidationFailure: Error, Equatable, Sendable {
    case textTooLarge(limit: Int, actual: Int)
    case unsupportedPayload
}

/// Performs deterministic, offline-only candidate extraction for the S1 Share Extension shell.
public struct SharePayloadExtractor: Sendable {
    public static let maximumPlainTextUTF8Bytes = 32 * 1_024
    public static let maximumURLUTF8Bytes = 4 * 1_024

    public init() {}

    public func extract(from payload: SharedPayload) throws -> ShareDraftCandidate {
        if let plainText = payload.plainText, plainText.utf8.count > Self.maximumPlainTextUTF8Bytes {
            throw SharePayloadValidationFailure.textTooLarge(
                limit: Self.maximumPlainTextUTF8Bytes,
                actual: plainText.utf8.count
            )
        }

        let acceptedURL = acceptedURL(from: payload.explicitURLString)
            ?? firstAcceptedURL(in: payload.plainText)
        let title = firstValidTitle(
            attributedTitle: payload.attributedTitle,
            plainText: payload.plainText,
            acceptedURL: acceptedURL
        )

        guard acceptedURL != nil || nonEmptyTrimmed(payload.plainText) != nil || title != nil else {
            throw SharePayloadValidationFailure.unsupportedPayload
        }

        return ShareDraftCandidate(
            acceptedURLString: acceptedURL,
            titleCandidate: title,
            plainText: payload.plainText
        )
    }

    private func acceptedURL(from value: String?) -> String? {
        guard let value, value.utf8.count <= Self.maximumURLUTF8Bytes,
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil
        else {
            return nil
        }
        return value
    }

    private func firstAcceptedURL(in text: String?) -> String? {
        guard let text else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        let matches = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            .matches(in: text, range: range)
        for match in matches ?? [] {
            guard let resultRange = Range(match.range, in: text) else { continue }
            let substring = String(text[resultRange])
            if let accepted = acceptedURL(from: substring) {
                return accepted
            }
        }
        return nil
    }

    private func firstValidTitle(
        attributedTitle: String?,
        plainText: String?,
        acceptedURL: String?
    ) -> String? {
        if let title = validPaperTitle(attributedTitle) {
            return title
        }

        guard let plainText else { return nil }
        for line in plainText.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != acceptedURL else { continue }
            if let title = validPaperTitle(trimmed) {
                return title
            }
        }
        return nil
    }

    private func validPaperTitle(_ value: String?) -> String? {
        guard let value else { return nil }
        return try? PaperContentValidator().validate(title: value, note: nil).title
    }

    private func nonEmptyTrimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
