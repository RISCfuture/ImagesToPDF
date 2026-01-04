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

  var nsImage: NSImage? {
    switch self {
      case let .image(image, _, size):
        return .init(cgImage: image, size: size)
      case .pdfPage:
        return nil
    }
  }

  var pdfPage: PDFPage? {
    switch self {
      case .image:
        return nil
      case let .pdfPage(page, _):
        return page
    }
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.path == rhs.path
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(path)
  }
}
