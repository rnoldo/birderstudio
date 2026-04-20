import Foundation
import Testing
@testable import BirderCore

@Suite("Analysis pipeline")
struct AnalysisPipelineTests {
    @Test func analyzesCR3Successfully() throws {
        guard Samples.isAvailable, let src = Samples.cr3Files.first else { return }

        let pipeline = SimpleAnalysisPipeline()
        let photoID = UUID()
        let result = try pipeline.analyze(photoID: photoID, imageURL: src)

        #expect(result.photoID == photoID)
        #expect(result.quality.sharpness >= 0.0 && result.quality.sharpness <= 1.0)
        #expect(result.quality.exposure >= 0.0 && result.quality.exposure <= 1.0)
        #expect(result.quality.overall >= 0.0 && result.quality.overall <= 1.0)
        #expect(result.featurePrint.count > 1000)
        #expect(result.quality.eyeSharpness == nil)
        #expect(result.quality.composition == nil)
        #expect(result.analyzedVersion == 1)
    }

    @Test func featurePrintsAreComparable() throws {
        guard Samples.isAvailable, Samples.cr3Files.count >= 2 else { return }

        let pipeline = SimpleAnalysisPipeline()
        let a = try pipeline.analyze(photoID: UUID(), imageURL: Samples.cr3Files[0])
        let b = try pipeline.analyze(photoID: UUID(), imageURL: Samples.cr3Files[1])

        let selfDistance = try FeaturePrintCompare.distance(a.featurePrint, a.featurePrint)
        let crossDistance = try FeaturePrintCompare.distance(a.featurePrint, b.featurePrint)
        #expect(selfDistance < 0.01)
        #expect(crossDistance > selfDistance)
    }

    @Test func sharpnessDifferentiatesBlurryFromSharp() throws {
        guard Samples.isAvailable, Samples.cr3Files.count >= 3 else { return }

        let pipeline = SimpleAnalysisPipeline()
        var scores: [(URL, Double)] = []
        for url in Samples.cr3Files.prefix(5) {
            let r = try pipeline.analyze(photoID: UUID(), imageURL: url)
            scores.append((url, r.quality.sharpness))
        }
        let sharpnessValues = scores.map { $0.1 }
        let spread = (sharpnessValues.max() ?? 0) - (sharpnessValues.min() ?? 0)
        #expect(spread > 0.02, "sharpness scores should vary across photos; got \(sharpnessValues)")
    }
}
