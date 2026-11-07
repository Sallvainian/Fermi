// Prints the text Vision recognises in an image, one line per row, to stdout.
// Used by scripts/ios-sim-check.sh to read the build id off a Simulator
// screenshot. Exits 1 if the image cannot be read or recognised.
//
// Recognition runs on the image at several scales and prints every line seen at
// each scale, in reading order, so a wrapped id stays contiguous within one
// scale. At native size Vision reads a letter in the 40-character hex id wrong
// (a `b` as a `6`), and a different scale reads it right; the caller still
// requires the exact id, so extra readings cannot produce a false match.
//
// Usage: ocr-text <image-path>
import Foundation
import Vision
import CoreGraphics
import ImageIO

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: ocr-text <image-path>\n".utf8))
    exit(2)
}

let path = CommandLine.arguments[1]
guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    FileHandle.standardError.write(Data("cannot read image: \(path)\n".utf8))
    exit(1)
}

func rescaled(_ image: CGImage, by scale: Double) -> CGImage? {
    if scale == 1 { return image }
    let width = Int(Double(image.width) * scale)
    let height = Int(Double(image.height) * scale)
    guard let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()
}

var recognisedAny = false
for scale in [1.0, 2.0, 3.0, 0.5] {
    guard let scaled = rescaled(image, by: scale) else { continue }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    do {
        try VNImageRequestHandler(cgImage: scaled, options: [:]).perform([request])
    } catch {
        FileHandle.standardError.write(Data("text recognition failed at scale \(scale): \(error)\n".utf8))
        continue
    }
    recognisedAny = true
    for observation in request.results ?? [] {
        if let top = observation.topCandidates(1).first {
            print(top.string)
        }
    }
}

if !recognisedAny {
    FileHandle.standardError.write(Data("text recognition failed: no usable image\n".utf8))
    exit(1)
}
