import Foundation

public struct Session: Identifiable, Sendable, Hashable, Codable {
    public var id: UUID
    public var name: String
    public var locationName: String?
    public var locationCoordinate: Coordinate?
    public var dateStart: Date
    public var dateEnd: Date
    public var createdAt: Date
    public var colorHex: String?
    public var iconName: String?

    public init(
        id: UUID = UUID(),
        name: String,
        locationName: String? = nil,
        locationCoordinate: Coordinate? = nil,
        dateStart: Date,
        dateEnd: Date,
        createdAt: Date = Date(),
        colorHex: String? = nil,
        iconName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.locationName = locationName
        self.locationCoordinate = locationCoordinate
        self.dateStart = dateStart
        self.dateEnd = dateEnd
        self.createdAt = createdAt
        self.colorHex = colorHex
        self.iconName = iconName
    }
}
