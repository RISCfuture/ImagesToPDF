import CoreGraphics
import Foundation

// A unit of content found while scanning the input. Each case holds only Sendable value
// types, so items can be produced concurrently; PDFKit objects are materialized later on
// PDFActor.
enum PDFItem: Sendable, Equatable, Hashable {
  // A decoded raster image to be drawn onto a generated page.
  case image(image: CGImage, path: String, size: NSSize)
  // A reference to one page of an existing PDF file on disk.
  case pdfPage(sourceURL: URL, pageIndex: Int, path: String)

  // The table-of-contents path this item occupies, derived from its location on disk.
  var path: String {
    switch self {
      case let .image(_, path, _), let .pdfPage(_, _, path):
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
