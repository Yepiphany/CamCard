import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import Vision

struct CardBoundary {
    // Normalized coordinates with the origin at the top left.
    var corners: [CGPoint]

    static let wholeImage = CardBoundary(corners: [
        CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
        CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 1)
    ])

    var isValid: Bool {
        corners.indices.allSatisfy { index in
            let a = corners[index]
            let b = corners[(index + 1) % 4]
            let c = corners[(index + 2) % 4]
            return (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x) > 0.001
        }
    }

    var rotated: CardBoundary {
        let indices = [3, 0, 1, 2]
        return CardBoundary(corners: indices.map {
            CGPoint(x: 1 - corners[$0].y, y: corners[$0].x)
        })
    }
}

struct ScanResult {
    let original: CGImage
    let source: CGImage
    let boundary: CardBoundary
    let corrected: CGImage
    let recognition: RecognitionRecord
    let needsManualCrop: Bool
}

enum ScanProcessor {
    private static let context = CIContext()

    enum ScanError: LocalizedError {
        case unreadableImage
        case invalidCrop

        var errorDescription: String? {
            switch self {
            case .unreadableImage: "无法读取这张图片，请重新选择。"
            case .invalidCrop: "裁剪区域无效，请调整四个角点。"
            }
        }
    }

    static func decode(_ data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2400
              ] as CFDictionary) else {
            throw ScanError.unreadableImage
        }
        return image
    }

    static func rotate(_ image: CGImage) throws -> CGImage {
        let rotated = CIImage(cgImage: image).oriented(.right)
        guard let result = context.createCGImage(rotated, from: rotated.extent) else {
            throw ScanError.unreadableImage
        }
        return result
    }

    static func recognize(original: CGImage, source: CGImage, boundary: CardBoundary? = nil) throws -> ScanResult {
        let detected = try boundary ?? detect(in: source)
        let selected = detected ?? .wholeImage
        let corrected = detected == nil ? source : try crop(source, to: selected)

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let supported = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"].filter(supported.contains)
        try VNImageRequestHandler(cgImage: corrected).perform([request])
        let regions = (request.results ?? []).compactMap { observation -> RecognitionRecord.TextRegion? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            return RecognitionRecord.TextRegion(
                text: candidate.string, x: box.minX, y: 1 - box.maxY,
                width: box.width, height: box.height
            )
        }
        let recognition = RecognitionRecord(
            languages: request.recognitionLanguages,
            rawText: regions.map(\.text).joined(separator: "\n"),
            regions: regions,
            candidates: ContactFields(),
            recognizedAt: .now
        )
        return ScanResult(original: original, source: source, boundary: selected,
                          corrected: corrected, recognition: recognition, needsManualCrop: detected == nil)
    }

    private static func detect(in image: CGImage) throws -> CardBoundary? {
        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.6
        request.minimumAspectRatio = 0.32
        request.minimumSize = 0.22
        request.maximumObservations = 4
        try VNImageRequestHandler(cgImage: image).perform([request])
        return request.results?.sorted {
            $0.boundingBox.width * $0.boundingBox.height > $1.boundingBox.width * $1.boundingBox.height
        }.lazy.map { rectangle in
            CardBoundary(corners: [
                rectangle.topLeft, rectangle.topRight, rectangle.bottomRight, rectangle.bottomLeft
            ].map { CGPoint(x: $0.x, y: 1 - $0.y) })
        }.first(where: \.isValid)
    }

    private static func crop(_ image: CGImage, to boundary: CardBoundary) throws -> CGImage {
        guard boundary.isValid else { throw ScanError.invalidCrop }
        let input = CIImage(cgImage: image)
        let points = boundary.corners.map {
            CGPoint(x: $0.x * input.extent.width, y: (1 - $0.y) * input.extent.height)
        }
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = input
        filter.topLeft = points[0]
        filter.topRight = points[1]
        filter.bottomRight = points[2]
        filter.bottomLeft = points[3]
        guard let output = filter.outputImage,
              !output.extent.isEmpty,
              let corrected = context.createCGImage(output, from: output.extent) else {
            throw ScanError.invalidCrop
        }
        return corrected
    }
}
