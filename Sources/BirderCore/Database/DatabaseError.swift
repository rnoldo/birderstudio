import Foundation

public enum BirderDatabaseError: Error, Sendable, CustomStringConvertible {
    case migrationFailed(underlying: String)
    case openFailed(path: String, underlying: String)
    case recordNotFound(type: String, id: String)
    case invalidEncoding(field: String, underlying: String)

    public var description: String {
        switch self {
        case .migrationFailed(let underlying):
            return "Database migration failed: \(underlying)"
        case .openFailed(let path, let underlying):
            return "Failed to open database at \(path): \(underlying)"
        case .recordNotFound(let type, let id):
            return "\(type) with id \(id) not found"
        case .invalidEncoding(let field, let underlying):
            return "Invalid encoding for \(field): \(underlying)"
        }
    }
}
