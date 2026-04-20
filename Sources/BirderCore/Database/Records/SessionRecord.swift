import Foundation
import GRDB

struct SessionRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "sessions"

    var id: String
    var name: String
    var locationName: String?
    var locationLat: Double?
    var locationLon: Double?
    var dateStart: Double
    var dateEnd: Double
    var createdAt: Double
    var colorHex: String?
    var iconName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case locationName = "location_name"
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case dateStart = "date_start"
        case dateEnd = "date_end"
        case createdAt = "created_at"
        case colorHex = "color_hex"
        case iconName = "icon_name"
    }
}

extension SessionRecord {
    init(from domain: Session) {
        self.id = domain.id.uuidString
        self.name = domain.name
        self.locationName = domain.locationName
        self.locationLat = domain.locationCoordinate?.latitude
        self.locationLon = domain.locationCoordinate?.longitude
        self.dateStart = domain.dateStart.timeIntervalSinceReferenceDate
        self.dateEnd = domain.dateEnd.timeIntervalSinceReferenceDate
        self.createdAt = domain.createdAt.timeIntervalSinceReferenceDate
        self.colorHex = domain.colorHex
        self.iconName = domain.iconName
    }

    func toDomain() throws -> Session {
        guard let uuid = UUID(uuidString: id) else {
            throw BirderDatabaseError.invalidEncoding(field: "sessions.id", underlying: id)
        }
        let coordinate: Coordinate? = {
            guard let lat = locationLat, let lon = locationLon else { return nil }
            return Coordinate(latitude: lat, longitude: lon)
        }()
        return Session(
            id: uuid,
            name: name,
            locationName: locationName,
            locationCoordinate: coordinate,
            dateStart: Date(timeIntervalSinceReferenceDate: dateStart),
            dateEnd: Date(timeIntervalSinceReferenceDate: dateEnd),
            createdAt: Date(timeIntervalSinceReferenceDate: createdAt),
            colorHex: colorHex,
            iconName: iconName
        )
    }
}
