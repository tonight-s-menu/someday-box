import Foundation

public enum DomainLimits {
    public static let titleCharacterCount = 120
    public static let titleUTF8ByteCount = 512
    public static let noteCharacterCount = 1_000
    public static let noteUTF8ByteCount = 4_096
    public static let openRawValueUTF8ByteCount = 64
}

public enum TextValidationFailure: Error, Equatable, Sendable {
    case empty
    case tooManyCharacters(limit: Int, actual: Int)
    case tooManyUTF8Bytes(limit: Int, actual: Int)
    case unsupportedControlCharacter
}

public enum RawValueValidationFailure: Error, Equatable, Sendable {
    case empty
    case tooManyUTF8Bytes(limit: Int, actual: Int)
    case notPrintable
}

public enum BoxItemValidationFailure: Error, Equatable, Sendable {
    case title(TextValidationFailure)
    case note(TextValidationFailure)
    case durationRawValue(RawValueValidationFailure)
    case lifecycleCompletionMismatch
}

public struct ValidatedPaperContent: Equatable, Sendable {
    public let title: String
    public let note: String?

    public init(title: String, note: String?) {
        self.title = title
        self.note = note
    }
}

public struct PaperContentValidator: Sendable {
    public init() {}

    public func validate(title: String, note: String?) throws -> ValidatedPaperContent {
        guard !title.unicodeScalars.contains(where: Self.isC0Control) else {
            throw BoxItemValidationFailure.title(.unsupportedControlCharacter)
        }

        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        try Self.validateBounds(
            normalizedTitle,
            characterLimit: DomainLimits.titleCharacterCount,
            byteLimit: DomainLimits.titleUTF8ByteCount,
            wrap: BoxItemValidationFailure.title
        )

        if let note {
            guard !note.unicodeScalars.contains(where: Self.isUnsupportedNoteControl) else {
                throw BoxItemValidationFailure.note(.unsupportedControlCharacter)
            }
            try Self.validateOptionalBounds(
                note,
                characterLimit: DomainLimits.noteCharacterCount,
                byteLimit: DomainLimits.noteUTF8ByteCount,
                wrap: BoxItemValidationFailure.note
            )
        }

        return ValidatedPaperContent(title: normalizedTitle, note: note)
    }

    public func validate(_ item: BoxItem) throws {
        _ = try validate(title: item.title, note: item.note)
        try OpenRawValueValidator().validate(item.durationBucketRaw)
        guard (item.lifecycle == .completed) == (item.completedAt != nil) else {
            throw BoxItemValidationFailure.lifecycleCompletionMismatch
        }
    }

    private static func validateBounds(
        _ value: String,
        characterLimit: Int,
        byteLimit: Int,
        wrap: (TextValidationFailure) -> BoxItemValidationFailure
    ) throws {
        guard !value.isEmpty else { throw wrap(.empty) }
        try validateOptionalBounds(value, characterLimit: characterLimit, byteLimit: byteLimit, wrap: wrap)
    }

    private static func validateOptionalBounds(
        _ value: String,
        characterLimit: Int,
        byteLimit: Int,
        wrap: (TextValidationFailure) -> BoxItemValidationFailure
    ) throws {
        guard value.count <= characterLimit else {
            throw wrap(.tooManyCharacters(limit: characterLimit, actual: value.count))
        }
        let byteCount = value.utf8.count
        guard byteCount <= byteLimit else {
            throw wrap(.tooManyUTF8Bytes(limit: byteLimit, actual: byteCount))
        }
    }

    private static func isC0Control(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value <= 0x1F
    }

    private static func isUnsupportedNoteControl(_ scalar: Unicode.Scalar) -> Bool {
        isC0Control(scalar) && scalar != "\t" && scalar != "\n"
    }
}

public struct OpenRawValueValidator: Sendable {
    public init() {}

    public func validate(_ value: String, requiresPrintableASCII: Bool = false) throws {
        guard !value.isEmpty else { throw RawValueValidationFailure.empty }
        let byteCount = value.utf8.count
        guard byteCount <= DomainLimits.openRawValueUTF8ByteCount else {
            throw RawValueValidationFailure.tooManyUTF8Bytes(
                limit: DomainLimits.openRawValueUTF8ByteCount,
                actual: byteCount
            )
        }
        if requiresPrintableASCII {
            guard value.unicodeScalars.allSatisfy({ 0x20...0x7E ~= $0.value }) else {
                throw RawValueValidationFailure.notPrintable
            }
        }
    }
}
