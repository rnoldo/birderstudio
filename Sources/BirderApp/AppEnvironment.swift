import Foundation
import SwiftUI
import BirderCore

@MainActor
final class AppEnvironment: ObservableObject {
    @Published private(set) var bootstrapError: String?
    @Published private(set) var storage: StorageLocations?
    @Published private(set) var database: BirderDatabase?
    @Published private(set) var importService: ImportService?
    @Published private(set) var sessionRepo: SessionRepository?
    @Published private(set) var photoRepo: PhotoRepository?

    @Published var sessions: [Session] = []
    @Published var selectedSessionID: Session.ID?

    let bookmarks = BookmarkStore(mode: .minimal)
    private var sessionObservationTask: Task<Void, Never>?

    deinit {
        sessionObservationTask?.cancel()
    }

    func bootstrap() async {
        guard database == nil else { return }
        do {
            let locations = try StorageLocations.userDefault()
            try locations.ensureDirectoriesExist()
            let db = try BirderDatabase(location: .file(locations.databaseURL))
            let importer = ImportService(
                database: db,
                storage: locations,
                bookmarks: bookmarks
            )
            let sessionRepo = SessionRepository(database: db)
            let photoRepo = PhotoRepository(database: db)

            self.storage = locations
            self.database = db
            self.importService = importer
            self.sessionRepo = sessionRepo
            self.photoRepo = photoRepo

            startObservingSessions(with: sessionRepo)
        } catch {
            self.bootstrapError = "Failed to open library: \(error)"
        }
    }

    private func startObservingSessions(with repo: SessionRepository) {
        sessionObservationTask?.cancel()
        sessionObservationTask = Task { [weak self] in
            do {
                for try await sessions in repo.observeAll() {
                    await MainActor.run { self?.sessions = sessions }
                }
            } catch {
                await MainActor.run { self?.bootstrapError = "Session stream failed: \(error)" }
            }
        }
    }

    func createSession(name: String = "New Session") async {
        guard let repo = sessionRepo else { return }
        let now = Date()
        let session = Session(
            name: name,
            dateStart: now,
            dateEnd: now
        )
        do {
            try await repo.save(session)
            selectedSessionID = session.id
        } catch {
            bootstrapError = "Create session failed: \(error)"
        }
    }

    func deleteSession(_ id: UUID) async {
        guard let repo = sessionRepo else { return }
        do {
            try await repo.delete(id: id)
            if selectedSessionID == id { selectedSessionID = nil }
        } catch {
            bootstrapError = "Delete session failed: \(error)"
        }
    }
}
