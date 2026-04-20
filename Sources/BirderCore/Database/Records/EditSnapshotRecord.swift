import Foundation
import GRDB

struct EditSnapshotRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "edits"

    var id: String
    var photoId: String
    var editJson: String
    var name: String?
    var createdAt: Double
    var updatedAt: Double
    var isCurrent: Int

    enum CodingKeys: String, CodingKey {
        case id
        case photoId = "photo_id"
        case editJson = "edit_json"
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isCurrent = "is_current"
    }
}

extension EditSnapshotRecord {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    init(from domain: EditSnapshot) throws {
        let data = try Self.encoder.encode(domain.graph)
        guard let json = String(data: data, encoding: .utf8) else {
            throw BirderDatabaseError.invalidEncoding(field: "edits.edit_json", underlying: "utf8 conversion failed")
        }
        self.id = domain.id.uuidString
        self.photoId = domain.photoID.uuidString
        self.editJson = json
        self.name = domain.name
        self.createdAt = domain.createdAt.timeIntervalSinceReferenceDate
        self.updatedAt = domain.updatedAt.timeIntervalSinceReferenceDate
        self.isCurrent = domain.isCurrent ? 1 : 0
    }

    func toDomain() throws -> EditSnapshot {
        guard let uuid = UUID(uuidString: id) else {
            throw BirderDatabaseError.invalidEncoding(field: "edits.id", underlying: id)
        }
        guard let photoUUID = UUID(uuidString: photoId) else {
            throw BirderDatabaseError.invalidEncoding(field: "edits.photo_id", underlying: photoId)
        }
        guard let data = editJson.data(using: .utf8) else {
            throw BirderDatabaseError.invalidEncoding(field: "edits.edit_json", underlying: "utf8 decode failed")
        }
        let graph = try Self.decoder.decode(EditGraph.self, from: data)
        return EditSnapshot(
            id: uuid,
            photoID: photoUUID,
            graph: graph,
            name: name,
            createdAt: Date(timeIntervalSinceReferenceDate: createdAt),
            updatedAt: Date(timeIntervalSinceReferenceDate: updatedAt),
            isCurrent: isCurrent != 0
        )
    }
}
