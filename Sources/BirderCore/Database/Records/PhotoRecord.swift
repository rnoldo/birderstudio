import Foundation
import GRDB

struct PhotoRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "photos"

    var id: String
    var sessionId: String
    var fileBookmark: Data
    var fileUrlCached: String
    var checksum: String
    var fileSize: Int64
    var format: String

    var capturedAt: Double
    var cameraMake: String?
    var cameraModel: String?
    var lensModel: String?
    var focalLength: Double?
    var iso: Int?
    var shutterDenom: Int?
    var aperture: Double?
    var gpsLat: Double?
    var gpsLon: Double?
    var imageWidth: Int
    var imageHeight: Int

    var status: Int
    var importedAt: Double
    var analyzedAt: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case fileBookmark = "file_bookmark"
        case fileUrlCached = "file_url_cached"
        case checksum
        case fileSize = "file_size"
        case format
        case capturedAt = "captured_at"
        case cameraMake = "camera_make"
        case cameraModel = "camera_model"
        case lensModel = "lens_model"
        case focalLength = "focal_length"
        case iso
        case shutterDenom = "shutter_denom"
        case aperture
        case gpsLat = "gps_lat"
        case gpsLon = "gps_lon"
        case imageWidth = "image_width"
        case imageHeight = "image_height"
        case status
        case importedAt = "imported_at"
        case analyzedAt = "analyzed_at"
    }
}

extension PhotoRecord {
    init(from domain: Photo) {
        self.id = domain.id.uuidString
        self.sessionId = domain.sessionID.uuidString
        self.fileBookmark = domain.fileBookmark
        self.fileUrlCached = domain.fileURLCached.absoluteString
        self.checksum = domain.checksum
        self.fileSize = domain.fileSize
        self.format = domain.format.rawValue
        self.capturedAt = domain.captured.timeIntervalSince1970
        self.cameraMake = domain.exif.camera.make
        self.cameraModel = domain.exif.camera.model
        self.lensModel = domain.exif.lens
        self.focalLength = domain.exif.focalLength
        self.iso = domain.exif.iso
        self.shutterDenom = domain.exif.shutter?.denominator
        self.aperture = domain.exif.aperture
        self.gpsLat = domain.exif.gps?.latitude
        self.gpsLon = domain.exif.gps?.longitude
        self.imageWidth = domain.pixelSize.width
        self.imageHeight = domain.pixelSize.height
        self.status = domain.status.rawValue
        self.importedAt = domain.importedAt.timeIntervalSince1970
        self.analyzedAt = domain.analyzedAt.map { $0.timeIntervalSince1970 }
    }

    func toDomain() throws -> Photo {
        guard let uuid = UUID(uuidString: id) else {
            throw BirderDatabaseError.invalidEncoding(field: "photos.id", underlying: id)
        }
        guard let sessionUUID = UUID(uuidString: sessionId) else {
            throw BirderDatabaseError.invalidEncoding(field: "photos.session_id", underlying: sessionId)
        }
        guard let format = FileFormat(rawValue: format) else {
            throw BirderDatabaseError.invalidEncoding(field: "photos.format", underlying: format)
        }
        guard let url = URL(string: fileUrlCached) else {
            throw BirderDatabaseError.invalidEncoding(field: "photos.file_url_cached", underlying: fileUrlCached)
        }
        let status = ProcessingStatus(rawValue: status) ?? .imported

        let gps: Coordinate? = {
            guard let lat = gpsLat, let lon = gpsLon else { return nil }
            return Coordinate(latitude: lat, longitude: lon)
        }()
        let exif = EXIF(
            camera: CameraInfo(make: cameraMake, model: cameraModel),
            lens: lensModel,
            focalLength: focalLength,
            iso: iso,
            shutter: shutterDenom.map { ShutterSpeed(denominator: $0) },
            aperture: aperture,
            gps: gps
        )

        return Photo(
            id: uuid,
            sessionID: sessionUUID,
            fileBookmark: fileBookmark,
            fileURLCached: url,
            checksum: checksum,
            fileSize: fileSize,
            format: format,
            captured: Date(timeIntervalSince1970: capturedAt),
            exif: exif,
            pixelSize: PixelSize(width: imageWidth, height: imageHeight),
            status: status,
            importedAt: Date(timeIntervalSince1970: importedAt),
            analyzedAt: analyzedAt.map { Date(timeIntervalSince1970: $0) }
        )
    }
}
