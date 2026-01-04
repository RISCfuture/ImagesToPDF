import Foundation

enum Errors: Error {
  case couldntWritePDF(url: URL)
  case invalidInputDirectory(url: URL)
  case imageLoadFailed(url: URL)
  case pdfCreationFailed
}

extension Errors: LocalizedError {
  var errorDescription: String? {
    switch self {
      case let .couldntWritePDF(url):
        return "Couldn't create PDF file at “\(url.path)”"
      case let .invalidInputDirectory(url):
        return "Invalid input directory: “\(url.path)”"
      case let .imageLoadFailed(url):
        return "Failed to load image at “\(url.path)”"
      case .pdfCreationFailed:
        return "Failed to create PDF document"
    }
  }
}
