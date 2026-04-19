import Foundation

public enum ProcessingStatus: Int, Sendable, Codable, CaseIterable {
    case imported = 0
    case analyzing = 1
    case analyzed = 2
    case failed = 3
}

public struct Photo: Identifiable, Sendable, Hashable, Codable {
    public var id: UUID
    public var sessionID: UUID
    public var fileBookmark: Data
    public var fileURLCached: URL
    public var checksum: String
    public var fileSize: Int64
    public var format: FileFormat
    public var captured: Date
    public var exif: EXIF
    public var pixelSize: PixelSize
    public var status: ProcessingStatus
    public var importedAt: Date
    public var analyzedAt: Date?

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        fileBookmark: Data,
        fileURLCached: URL,
        checksum: String,
        fileSize: Int64,
        format: FileFormat,
        captured: Date,
        exif: EXIF = EXIF(),
        pixelSize: PixelSize,
        status: ProcessingStatus = .imported,
        importedAt: Date = Date(),
        analyzedAt: Date? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.fileBookmark = fileBookmark
        self.fileURLCached = fileURLCached
        self.checksum = checksum
        self.fileSize = fileSize
        self.format = format
        self.captured = captured
        self.exif = exif
        self.pixelSize = pixelSize
        self.status = status
        self.importedAt = importedAt
        self.analyzedAt = analyzedAt
    }
}
