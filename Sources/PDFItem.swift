import AppKit
@preconcurrency import PDFKit

enum PDFItem: @unchecked Sendable, Equatable, Hashable {
  case image(image: CGImage, path: String, size: NSSize)
  case pdfPage(page: PDFPage, path: String)

  var path: String {
    switch self {
      case let .image(_, path, _), let .pdfPage(_, path):
        return path
    }
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.path == rhs.path
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(path)
  }
}
