import Foundation
import ImageIO

public enum EXIFExtractionError: Error, Sendable {
    case cannotOpenImage(path: String)
    case missingPixelDimensions(path: String)
}

public struct ExtractedMetadata: Sendable, Equatable {
    public let captured: Date?
    public let pixelSize: PixelSize
    public let exif: EXIF
    public let uti: String?
}

public enum EXIFExtractor {
    /// Reads EXIF + TIFF + GPS metadata via ImageIO. Works on CR3/CR2/NEF/ARW/DNG/
    /// RAF/ORF/RW2/JPEG/HEIC. Uses a sync CGImageSourceCreateWithURL so the caller
    /// MUST run this off the main actor.
    public static func extract(from url: URL) throws -> ExtractedMetadata {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw EXIFExtractionError.cannotOpenImage(path: url.path)
        }
        let uti = CGImageSourceGetType(src) as String?
        guard let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else {
            throw EXIFExtractionError.missingPixelDimensions(path: url.path)
        }

        let width = props[kCGImagePropertyPixelWidth] as? Int
        let height = props[kCGImagePropertyPixelHeight] as? Int
        guard let w = width, let h = height, w > 0, h > 0 else {
            throw EXIFExtractionError.missingPixelDimensions(path: url.path)
        }
        let pixelSize = PixelSize(width: w, height: h)

        let exifDict = props[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let tiffDict = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let gpsDict = props[kCGImagePropertyGPSDictionary] as? [CFString: Any] ?? [:]

        let iso = parseISO(from: exifDict)
        let shutter: ShutterSpeed? = (exifDict[kCGImagePropertyExifExposureTime] as? Double)
            .flatMap(makeShutter)
        let aperture = exifDict[kCGImagePropertyExifFNumber] as? Double
        let focal = exifDict[kCGImagePropertyExifFocalLength] as? Double
        let lens = exifDict[kCGImagePropertyExifLensModel] as? String
        let captured = parseDate(exifDict[kCGImagePropertyExifDateTimeOriginal] as? String)
            ?? parseDate(tiffDict[kCGImagePropertyTIFFDateTime] as? String)

        let make = tiffDict[kCGImagePropertyTIFFMake] as? String
        let model = tiffDict[kCGImagePropertyTIFFModel] as? String
        let camera = CameraInfo(make: make, model: model)

        let gps = parseGPS(gpsDict)

        let exif = EXIF(
            camera: camera,
            lens: lens,
            focalLength: focal,
            iso: iso,
            shutter: shutter,
            aperture: aperture,
            gps: gps
        )

        return ExtractedMetadata(captured: captured, pixelSize: pixelSize, exif: exif, uti: uti)
    }

    private static func parseISO(from exif: [CFString: Any]) -> Int? {
        if let arr = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int], let first = arr.first {
            return first
        }
        if let single = exif[kCGImagePropertyExifISOSpeed] as? Int {
            return single
        }
        if let double = exif[kCGImagePropertyExifISOSpeed] as? Double {
            return Int(double)
        }
        return nil
    }

    private static func makeShutter(from exposureTime: Double) -> ShutterSpeed? {
        guard exposureTime > 0 else { return nil }
        let denom = Int((1.0 / exposureTime).rounded())
        guard denom > 0 else { return nil }
        return ShutterSpeed(denominator: denom)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        f.timeZone = TimeZone.current
        return f
    }()

    private static func parseDate(_ raw: String?) -> Date? {
        guard let s = raw else { return nil }
        return dateFormatter.date(from: s)
    }

    private static func parseGPS(_ dict: [CFString: Any]) -> Coordinate? {
        guard
            let lat = dict[kCGImagePropertyGPSLatitude] as? Double,
            let lon = dict[kCGImagePropertyGPSLongitude] as? Double
        else { return nil }
        let latRef = dict[kCGImagePropertyGPSLatitudeRef] as? String ?? "N"
        let lonRef = dict[kCGImagePropertyGPSLongitudeRef] as? String ?? "E"
        let signedLat = latRef.uppercased() == "S" ? -lat : lat
        let signedLon = lonRef.uppercased() == "W" ? -lon : lon
        return Coordinate(latitude: signedLat, longitude: signedLon)
    }
}
