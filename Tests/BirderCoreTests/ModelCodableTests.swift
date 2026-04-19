import Foundation
import Testing
@testable import BirderCore

@Suite("Model Codable round-trip")
struct ModelCodableTests {
    private func roundtrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(value)
        return try decoder.decode(T.self, from: data)
    }

    @Test func photoRoundtrip() throws {
        let photo = Photo(
            sessionID: UUID(),
            fileBookmark: Data([0x01, 0x02, 0x03]),
            fileURLCached: URL(fileURLWithPath: "/tmp/sample.cr3"),
            checksum: "abc123",
            fileSize: 1_024_000,
            format: .cr3,
            captured: Date(timeIntervalSince1970: 1_700_000_000),
            exif: EXIF(
                camera: CameraInfo(make: "Canon", model: "R5"),
                lens: "RF 800 F11",
                focalLength: 800,
                iso: 3200,
                shutter: ShutterSpeed(denominator: 1600),
                aperture: 11,
                gps: Coordinate(latitude: 31.23, longitude: 121.47)
            ),
            pixelSize: PixelSize(width: 8192, height: 5464)
        )
        let decoded = try roundtrip(photo)
        #expect(decoded == photo)
    }

    @Test func sessionRoundtrip() throws {
        let session = Session(
            name: "崇明东滩 2026-04",
            locationName: "Chongming Dongtan",
            locationCoordinate: Coordinate(latitude: 31.5, longitude: 121.9),
            dateStart: Date(timeIntervalSince1970: 1_710_000_000),
            dateEnd: Date(timeIntervalSince1970: 1_710_014_400),
            colorHex: "#F5A623",
            iconName: "bird"
        )
        let decoded = try roundtrip(session)
        #expect(decoded == session)
    }

    @Test func photoAnalysisRoundtrip() throws {
        let analysis = PhotoAnalysis(
            photoID: UUID(),
            quality: QualityScores(
                overall: 0.82,
                sharpness: 0.91,
                exposure: 0.75,
                eyeSharpness: 0.88,
                composition: 0.70,
                sessionPercentile: 0.95
            ),
            featurePrint: Data(repeating: 0xAA, count: 128 * 4),
            sceneID: UUID(),
            isSceneBest: true
        )
        let decoded = try roundtrip(analysis)
        #expect(decoded == analysis)
    }

    @Test func birdDetectionRoundtrip() throws {
        let detection = BirdDetection(
            photoID: UUID(),
            bbox: NormalizedRect(x: 0.2, y: 0.3, width: 0.4, height: 0.3),
            confidence: 0.95,
            speciesID: "norcar",
            speciesConfidence: 0.87,
            speciesSource: .ml
        )
        let decoded = try roundtrip(detection)
        #expect(decoded == detection)
    }

    @Test func speciesRoundtrip() throws {
        let species = Species(
            id: "norcar",
            commonNameEN: "Northern Cardinal",
            commonNameZH: "主红雀",
            scientificName: "Cardinalis cardinalis",
            family: "Cardinalidae",
            familyZH: "美洲雀科",
            order: "Passeriformes"
        )
        let decoded = try roundtrip(species)
        #expect(decoded == species)
    }

    @Test func ratingRoundtrip() throws {
        let rating = PhotoRating(
            photoID: UUID(),
            decision: .accepted,
            star: 5,
            colorLabel: 3,
            note: "best of the morning"
        )
        let decoded = try roundtrip(rating)
        #expect(decoded == rating)
    }

    @Test func editGraphRoundtrip() throws {
        let graph = EditGraph(
            crop: CropParams(rect: NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)),
            exposure: ExposureParams(ev: 0.3, highlights: -20, shadows: 15),
            whiteBalance: WhiteBalanceParams(temperature: 200, tint: -10),
            sharpen: SharpenParams(amount: 30, radius: 1.2, featherAware: true),
            vibrance: VibranceParams(saturation: 5, vibrance: 15),
            preset: PresetApplication(presetID: "bird_portrait", strength: 1.0)
        )
        let decoded = try roundtrip(graph)
        #expect(decoded == graph)
    }

    @Test func editGraphEmptyIsDefault() throws {
        #expect(EditGraph.empty.version == 1)
        #expect(EditGraph.empty.crop == nil)
        #expect(EditGraph.empty.overlays.isEmpty)
    }

    @Test func fileFormatRawClassification() {
        #expect(FileFormat.cr3.isRaw)
        #expect(FileFormat.nef.isRaw)
        #expect(FileFormat.dng.isRaw)
        #expect(!FileFormat.jpeg.isRaw)
        #expect(!FileFormat.heic.isRaw)
    }

    @Test func fileFormatFromExtensionIsCaseInsensitive() {
        #expect(FileFormat.from(pathExtension: "CR3") == .cr3)
        #expect(FileFormat.from(pathExtension: "jpeg") == .jpeg)
        #expect(FileFormat.from(pathExtension: "xyz") == nil)
    }

    @Test func ratingStarClamping() {
        #expect(PhotoRating(photoID: UUID(), star: 10).star == 5)
        #expect(PhotoRating(photoID: UUID(), star: -3).star == 0)
        #expect(PhotoRating(photoID: UUID(), colorLabel: 20).colorLabel == 7)
    }
}
