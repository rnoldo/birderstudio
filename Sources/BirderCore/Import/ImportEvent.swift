import Foundation

public enum ImportEvent: Sendable, Equatable {
    case started(totalCount: Int)
    case imported(photoID: UUID, url: URL)
    case duplicateSkipped(url: URL, existingPhotoID: UUID)
    case failed(url: URL, message: String)
    case completed(imported: Int, skipped: Int, failed: Int)
}
