import Foundation
import GRDB

struct ProjectRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "projects"

    var id: String
    var name: String
    var createdAt: Double

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt = "created_at"
    }
}

extension ProjectRecord {
    init(from domain: Project) {
        self.id = domain.id.uuidString
        self.name = domain.name
        self.createdAt = domain.createdAt.timeIntervalSince1970
    }

    func toDomain() throws -> Project {
        guard let uuid = UUID(uuidString: id) else {
            throw BirderDatabaseError.invalidEncoding(field: "projects.id", underlying: id)
        }
        return Project(
            id: uuid,
            name: name,
            createdAt: Date(timeIntervalSince1970: createdAt)
        )
    }
}

struct ProjectPhotoRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "project_photos"

    var projectId: String
    var photoId: String
    var orderIdx: Int

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case photoId = "photo_id"
        case orderIdx = "order_idx"
    }
}

extension ProjectPhotoRecord {
    init(from domain: ProjectPhoto) {
        self.projectId = domain.projectID.uuidString
        self.photoId = domain.photoID.uuidString
        self.orderIdx = domain.orderIndex
    }

    func toDomain() throws -> ProjectPhoto {
        guard let projectUUID = UUID(uuidString: projectId),
              let photoUUID = UUID(uuidString: photoId) else {
            throw BirderDatabaseError.invalidEncoding(field: "project_photos", underlying: "uuid parse failed")
        }
        return ProjectPhoto(projectID: projectUUID, photoID: photoUUID, orderIndex: orderIdx)
    }
}
