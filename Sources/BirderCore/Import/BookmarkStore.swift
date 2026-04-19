import Foundation

public enum BookmarkError: Error, Sendable {
    case resolveFailed(underlying: String)
    case stale
    case cannotAccess
}

public struct BookmarkStore: Sendable {
    public enum Mode: Sendable {
        case securityScoped
        case minimal
    }

    public let mode: Mode

    public init(mode: Mode = .securityScoped) {
        self.mode = mode
    }

    public func createBookmark(for url: URL) throws -> Data {
        let options: URL.BookmarkCreationOptions
        switch mode {
        case .securityScoped:
            options = [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
        case .minimal:
            options = []
        }
        return try url.bookmarkData(
            options: options,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    public func resolve(_ data: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let options: URL.BookmarkResolutionOptions
        switch mode {
        case .securityScoped:
            options = [.withSecurityScope]
        case .minimal:
            options = []
        }
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: data,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw BookmarkError.resolveFailed(underlying: String(describing: error))
        }
        return (url, isStale)
    }

    public func withScopedAccess<T: Sendable>(
        to data: Data,
        _ body: (URL) throws -> T
    ) throws -> T {
        let (url, _) = try resolve(data)
        switch mode {
        case .securityScoped:
            guard url.startAccessingSecurityScopedResource() else {
                throw BookmarkError.cannotAccess
            }
            defer { url.stopAccessingSecurityScopedResource() }
            return try body(url)
        case .minimal:
            return try body(url)
        }
    }
}
