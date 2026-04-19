import Foundation

public struct Project: Identifiable, Sendable, Hashable, Codable {
    public var id: UUID
    public var name: String
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

public struct ProjectPhoto: Sendable, Hashable, Codable {
    public var projectID: UUID
    public var photoID: UUID
    public var orderIndex: Int

    public init(projectID: UUID, photoID: UUID, orderIndex: Int) {
        self.projectID = projectID
        self.photoID = photoID
        self.orderIndex = orderIndex
    }
}
