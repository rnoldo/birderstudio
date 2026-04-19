import Foundation

public struct EditSnapshot: Identifiable, Sendable, Hashable, Codable {
    public var id: UUID
    public var photoID: UUID
    public var graph: EditGraph
    public var name: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var isCurrent: Bool

    public init(
        id: UUID = UUID(),
        photoID: UUID,
        graph: EditGraph,
        name: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isCurrent: Bool = false
    ) {
        self.id = id
        self.photoID = photoID
        self.graph = graph
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isCurrent = isCurrent
    }
}
