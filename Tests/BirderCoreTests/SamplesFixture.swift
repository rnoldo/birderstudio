import Foundation

enum Samples {
    static let envKey = "BIRDER_TEST_SAMPLES_DIR"

    static var directory: URL? {
        if let env = ProcessInfo.processInfo.environment[envKey], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        let fallback = URL(fileURLWithPath: "/Users/bruce.y/GitCode/ProjectKestrel/test_imgs", isDirectory: true)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: fallback.path, isDirectory: &isDir), isDir.boolValue {
            return fallback
        }
        return nil
    }

    static var cr3Files: [URL] {
        guard let dir = directory else { return [] }
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return contents.filter { $0.pathExtension.lowercased() == "cr3" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static var isAvailable: Bool { !cr3Files.isEmpty }
}
