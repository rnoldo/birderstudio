import Foundation
import GRDB

struct SpeciesRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "species"

    var id: String
    var commonNameEn: String
    var commonNameZh: String?
    var scientificName: String
    var family: String?
    var familyZh: String?
    var orderName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case commonNameEn = "common_name_en"
        case commonNameZh = "common_name_zh"
        case scientificName = "scientific_name"
        case family
        case familyZh = "family_zh"
        case orderName = "order_name"
    }
}

extension SpeciesRecord {
    init(from domain: Species) {
        self.id = domain.id
        self.commonNameEn = domain.commonNameEN
        self.commonNameZh = domain.commonNameZH
        self.scientificName = domain.scientificName
        self.family = domain.family
        self.familyZh = domain.familyZH
        self.orderName = domain.order
    }

    func toDomain() -> Species {
        Species(
            id: id,
            commonNameEN: commonNameEn,
            commonNameZH: commonNameZh,
            scientificName: scientificName,
            family: family,
            familyZH: familyZh,
            order: orderName
        )
    }
}
