import Foundation
import Vision

/// On-device OCR. Returning nil lets older systems fall back to Tesseract.
enum ReceiptTextRecognizer {
  static func read(_ data: Data) throws -> String? {
    guard #available(iOS 15.0, macOS 12.0, *) else { return nil }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    let supported = try request.supportedRecognitionLanguages()
    guard supported.contains("th-TH") else { return nil }
    request.recognitionLanguages = ["th-TH", "en-US"]
    try VNImageRequestHandler(data: data, options: [:]).perform([request])

    // Bank slips place the label at the left and amount at the far right.
    // Reassemble observations by visual row, not by OCR block order.
    let observations = (request.results ?? []).sorted {
      $0.boundingBox.midY > $1.boundingBox.midY
    }
    var rows: [[VNRecognizedTextObservation]] = []
    for observation in observations {
      if let index = rows.firstIndex(where: { row in
        guard let first = row.first else { return false }
        let a = first.boundingBox
        let b = observation.boundingBox
        let overlap = min(a.maxY, b.maxY) - max(a.minY, b.minY)
        // Amounts often use much larger type than their label. Match shared
        // vertical space instead of requiring nearly identical text centers.
        return overlap > min(a.height, b.height) * 0.6
      }) {
        rows[index].append(observation)
      } else {
        rows.append([observation])
      }
    }
    return rows.map { row in
      row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: " ")
    }.joined(separator: "\n")
  }
}
