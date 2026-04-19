import Foundation
import GRDB

public final class BirderDatabase: Sendable {
    public enum Location: Sendable {
        case inMemory
        case file(URL)

        var description: String {
            switch self {
            case .inMemory: "in-memory"
            case .file(let url): url.path
            }
        }
    }

    private let writer: any DatabaseWriter
    public var reader: any DatabaseReader { writer }

    public init(location: Location) throws {
        do {
            switch location {
            case .inMemory:
                self.writer = try DatabaseQueue()
            case .file(let url):
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                var config = Configuration()
                config.prepareDatabase { db in
                    try db.execute(sql: "PRAGMA journal_mode = WAL;")
                    try db.execute(sql: "PRAGMA foreign_keys = ON;")
                }
                self.writer = try DatabasePool(path: url.path, configuration: config)
            }
        } catch {
            throw BirderDatabaseError.openFailed(path: location.description, underlying: "\(error)")
        }

        do {
            try migrate()
        } catch {
            throw BirderDatabaseError.migrationFailed(underlying: "\(error)")
        }
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        SchemaMigrator.registerAll(into: &migrator)
        try migrator.migrate(writer)
    }

    public func write<T: Sendable>(_ updates: @Sendable (Database) throws -> T) async throws -> T {
        try await writer.write(updates)
    }

    public func read<T: Sendable>(_ value: @Sendable (Database) throws -> T) async throws -> T {
        try await writer.read(value)
    }
}

public extension BirderDatabase {
    static func defaultLibraryURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base
            .appendingPathComponent("BirderStudio", isDirectory: true)
            .appendingPathComponent("library.sqlite")
    }
}
