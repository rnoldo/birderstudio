import Foundation
import CoreGraphics
import ImageIO
import Vision

/// Stub analysis pipeline used for the culling MVP.
///
/// - Sharpness: Laplacian variance on a ≤512-px grayscale downscale, log-scaled.
/// - Exposure: middlenesss + clip penalty on the same grayscale histogram.
/// - Feature print: Vision's `VNGenerateImageFeaturePrintRequest`, archived via
///   NSKeyedArchiver so `VNFeaturePrintObservation.computeDistance` can be used
///   for similarity clustering later.
///
/// Session percentile is left as 0.5 per-photo; `AnalysisService` recomputes it
/// after a batch finishes so the score is library-relative.
public struct SimpleAnalysisPipeline: AnalysisPipeline {
    public init() {}

    // Apple's RawCamera framework deadlocks under concurrent RAW decoding
    // (the dispatch_barrier_sync inside IIOImageProviderInfo wedges when
    // hit from multiple threads). Serialize the decode-triggering calls
    // — CGContext.draw and VNImageRequestHandler.perform — behind a
    // process-global lock. CPU-side scoring stays parallel.
    private static let decodeLock = NSLock()

    public func analyze(photoID: UUID, imageURL: URL) throws -> PhotoAnalysis {
        let cgImage = try Self.loadCGImage(url: imageURL)

        Self.decodeLock.lock()
        let gray: GrayBuffer
        let featurePrint: Data
        do {
            gray = try Self.makeGrayBuffer(cgImage: cgImage, maxDim: 512)
            featurePrint = try Self.featurePrint(cgImage: cgImage)
            Self.decodeLock.unlock()
        } catch {
            Self.decodeLock.unlock()
            throw error
        }

        let sharpness = Self.laplacianVarianceScore(gray: gray)
        let exposure = Self.exposureScore(gray: gray)

        let overall = 0.7 * sharpness + 0.3 * exposure

        return PhotoAnalysis(
            photoID: photoID,
            quality: QualityScores(
                overall: overall,
                sharpness: sharpness,
                exposure: exposure,
                eyeSharpness: nil,
                composition: nil,
                sessionPercentile: 0.5
            ),
            featurePrint: featurePrint,
            sceneID: nil,
            isSceneBest: false,
            analyzedVersion: 1
        )
    }

    // MARK: - Image loading

    private static func loadCGImage(url: URL) throws -> CGImage {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw AnalysisError.imageLoadFailed(url)
        }
        return cg
    }

    private static func makeGrayBuffer(cgImage: CGImage, maxDim: Int) throws -> GrayBuffer {
        let srcW = cgImage.width
        let srcH = cgImage.height
        let scale = min(Double(maxDim) / Double(max(srcW, srcH)), 1.0)
        let w = max(1, Int(Double(srcW) * scale))
        let h = max(1, Int(Double(srcH) * scale))

        guard let space = CGColorSpace(name: CGColorSpace.linearGray) else {
            throw AnalysisError.contextCreationFailed
        }
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w,
            space: space,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw AnalysisError.contextCreationFailed
        }
        ctx.interpolationQuality = .medium
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else {
            throw AnalysisError.contextCreationFailed
        }
        let pixels = [UInt8](unsafeUninitializedCapacity: w * h) { buf, count in
            memcpy(buf.baseAddress, data, w * h)
            count = w * h
        }
        return GrayBuffer(pixels: pixels, width: w, height: h)
    }

    // MARK: - Sharpness (Laplacian variance)

    private static func laplacianVarianceScore(gray: GrayBuffer) -> Double {
        let w = gray.width
        let h = gray.height
        guard w > 2, h > 2 else { return 0.0 }

        var sum: Double = 0
        var sumSq: Double = 0
        var count: Double = 0
        let p = gray.pixels
        for y in 1..<(h - 1) {
            let row = y * w
            let rowUp = (y - 1) * w
            let rowDn = (y + 1) * w
            for x in 1..<(w - 1) {
                let c = Int(p[row + x])
                let u = Int(p[rowUp + x])
                let d = Int(p[rowDn + x])
                let l = Int(p[row + x - 1])
                let r = Int(p[row + x + 1])
                let lap = Double(4 * c - u - d - l - r)
                sum += lap
                sumSq += lap * lap
                count += 1
            }
        }
        let mean = sum / count
        let variance = max(0.0, sumSq / count - mean * mean)

        // Empirical normalization: blurry ≈ 10–50, sharp ≈ 500–3000, extreme ≈ 5000+.
        // Log-scale to compress the long tail, clamp to [0, 1].
        let maxRef = log1p(3000.0)
        return min(1.0, log1p(variance) / maxRef)
    }

    // MARK: - Exposure

    private static func exposureScore(gray: GrayBuffer) -> Double {
        var histogram = [Int](repeating: 0, count: 256)
        for px in gray.pixels {
            histogram[Int(px)] += 1
        }
        let total = Double(gray.pixels.count)
        guard total > 0 else { return 0.0 }

        let darkClip = Double(histogram[0..<5].reduce(0, +)) / total
        let brightClip = Double(histogram[251..<256].reduce(0, +)) / total

        var weightedSum: Int = 0
        for (i, c) in histogram.enumerated() {
            weightedSum += i * c
        }
        let meanBrightness = Double(weightedSum) / total / 255.0
        let middleness = max(0.0, 1.0 - abs(meanBrightness - 0.5) * 2.0)
        let clipPenalty = min(1.0, darkClip * 0.6 + brightClip * 0.9)

        let score = 0.6 * middleness + 0.4 * (1.0 - clipPenalty)
        return max(0.0, min(1.0, score))
    }

    // MARK: - Feature print

    private static func featurePrint(cgImage: CGImage) throws -> Data {
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNGenerateImageFeaturePrintRequest()
        do {
            try handler.perform([request])
        } catch {
            throw AnalysisError.featurePrintFailed("perform: \(error)")
        }
        guard let obs = request.results?.first else {
            throw AnalysisError.featurePrintFailed("no observations")
        }
        do {
            return try NSKeyedArchiver.archivedData(
                withRootObject: obs,
                requiringSecureCoding: true
            )
        } catch {
            throw AnalysisError.featurePrintFailed("archive: \(error)")
        }
    }
}

/// Compares two archived feature prints via `VNFeaturePrintObservation.computeDistance`.
/// Returns a Float distance (smaller = more similar). Typical thresholds:
///   - < 0.3  near-duplicate (same burst, same framing)
///   - 0.3–0.6 same scene, different framing
///   - > 0.6  different scene
public enum FeaturePrintCompare {
    public static func distance(_ lhs: Data, _ rhs: Data) throws -> Float {
        guard let a = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: VNFeaturePrintObservation.self,
            from: lhs
        ), let b = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: VNFeaturePrintObservation.self,
            from: rhs
        ) else {
            throw AnalysisError.featurePrintFailed("unarchive failed")
        }
        var distance: Float = .greatestFiniteMagnitude
        try a.computeDistance(&distance, to: b)
        return distance
    }
}

struct GrayBuffer: Sendable {
    let pixels: [UInt8]
    let width: Int
    let height: Int
}
