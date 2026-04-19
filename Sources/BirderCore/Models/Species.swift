import Foundation

public struct Species: Identifiable, Sendable, Hashable, Codable {
    public var id: String
    public var commonNameEN: String
    public var commonNameZH: String?
    public var scientificName: String
    public var family: String?
    public var familyZH: String?
    public var order: String?

    public init(
        id: String,
        commonNameEN: String,
        commonNameZH: String? = nil,
        scientificName: String,
        family: String? = nil,
        familyZH: String? = nil,
        order: String? = nil
    ) {
        self.id = id
        self.commonNameEN = commonNameEN
        self.commonNameZH = commonNameZH
        self.scientificName = scientificName
        self.family = family
        self.familyZH = familyZH
        self.order = order
    }
}
