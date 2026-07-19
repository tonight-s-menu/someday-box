import Foundation

public enum BackupFileReaderError: Error, Equatable, Sendable {
    case encodedByteLimitExceeded(limit: Int, actual: Int)
}

public struct BackupFileReader: Sendable {
    public init() {}

    public func read(from url: URL) throws -> Data {
        let limit = BackupFormatV2Limits.encodedByteCount
        if let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           fileSize > limit {
            throw BackupFileReaderError.encodedByteLimitExceeded(limit: limit, actual: fileSize)
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var result = Data()
        while true {
            let remainingThroughFirstInvalidByte = limit - result.count + 1
            let readCount = min(64 * 1_024, remainingThroughFirstInvalidByte)
            guard let chunk = try handle.read(upToCount: readCount), !chunk.isEmpty else { break }
            let (projectedCount, overflowed) = result.count.addingReportingOverflow(chunk.count)
            guard !overflowed, projectedCount <= limit else {
                throw BackupFileReaderError.encodedByteLimitExceeded(
                    limit: limit,
                    actual: overflowed ? .max : projectedCount
                )
            }
            result.append(chunk)
        }
        return result
    }
}
