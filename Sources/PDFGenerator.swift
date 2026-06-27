import Foundation
import Logging
import PDFKit

// Reads an existing PDF's page layout into Sendable descriptors without materializing pages;
// the pages themselves are built later during assembly.
@PDFActor
private func pdfPages(from fileURL: URL, parentPath: String, logger: Logger) -> [PDFItem] {
  guard let document = PDFDocument(url: fileURL) else {
    logger.info(
      "Skipping PDF: couldn't create PDFDocument",
      metadata: [
        "fileURL": "\(fileURL)"
      ]
    )
    return []
  }

  guard let relativePath = fileURL.deletingPathExtension().path(relativeTo: parentPath) else {
    logger.info(
      "Skipping PDF: couldn't compute relative path",
      metadata: [
        "fileURL": "\(fileURL)",
        "parentPath": "\(parentPath)"
      ]
    )
    return []
  }

  return (0..<document.pageCount).map { pageIndex in
    let pagePath = pageIndex == 0 ? relativePath : "\(relativePath)/Page \(pageIndex + 1)"
    return .pdfPage(sourceURL: fileURL, pageIndex: pageIndex, path: pagePath)
  }
}

/// Generates PDF documents from a directory of images and existing PDFs.
///
/// The generator recursively scans the input directory for supported image formats
/// and PDF files, combining them into a single PDF with a table of contents based
/// on the directory structure.
class PDFGenerator {
  private static let logger = Logger(label: "codes.tim.ImagesToPDF.PDFGenerator")
  private static let imageCompressionQuality = 0.9

  private let input: URL
  private let title: String
  private let pageSize: CGSize

  /// File extensions that will be included in the generated PDF.
  var allowedSuffixes = [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".pdf"]

  /// Creates a new PDF generator.
  /// - Parameters:
  ///   - input: The directory containing images and PDFs to combine.
  ///   - title: The title for the PDF's table of contents.
  ///   - pageSize: The page dimensions for the output PDF.
  init(input: URL, title: String, pageSize: CGSize) {
    self.input = input
    self.title = title
    self.pageSize = pageSize
  }

  /// Generates a PDF from the input directory and writes it to the specified URL.
  /// - Parameter output: The file URL where the PDF will be written.
  /// - Throws: `Errors.invalidInputDirectory` if the input cannot be enumerated,
  ///           or `Errors.couldntWritePDF` if writing fails.
  func generate(to output: URL) async throws {
    let images = try await loadImages()
    try await writePDF(images: images, to: output)
  }

  private func loadImages() async throws -> [PDFItem] {
    let allowedSuffixes = self.allowedSuffixes,
      parentPath = self.input.path(percentEncoded: false)

    return try await withThrowingTaskGroup(of: [PDFItem].self) { group in
      guard
        let enumerator = FileManager.default.enumerator(
          at: input,
          includingPropertiesForKeys: [.isRegularFileKey, .nameKey, .pathKey],
          options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
      else {
        throw Errors.invalidInputDirectory(url: input)
      }
      let allURLs = enumerator.compactMap { $0 as? URL }
      for fileURL in allURLs {
        group.addTask { () -> [PDFItem] in
          guard
            let resourceValues = try? fileURL.resourceValues(forKeys: [
              .isRegularFileKey, .nameKey, .pathKey
            ]),
            let isRegularFile = resourceValues.isRegularFile,
            let name = resourceValues.name,
            let path = resourceValues.path
          else {
            Self.logger.info(
              "Skipping file: couldn't load resource values",
              metadata: [
                "fileURL": "\(fileURL)"
              ]
            )
            return []
          }
          guard isRegularFile else { return [] }
          guard allowedSuffixes.contains(where: { name.hasSuffix($0) }) else {
            Self.logger.info(
              "Skipping file: not an image or PDF file",
              metadata: [
                "path": "\(path)"
              ]
            )
            return []
          }

          if name.hasSuffix(".pdf") {
            return await pdfPages(from: fileURL, parentPath: parentPath, logger: Self.logger)
          }

          guard let nsImage = NSImage(contentsOfFile: path) else {
            Self.logger.info(
              "Skipping file: couldn't create NSImage",
              metadata: [
                "fileURL": "\(fileURL)"
              ]
            )
            return []
          }
          var imageRect = CGRect(origin: .zero, size: nsImage.size)
          guard let cgImage = nsImage.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
          else {
            Self.logger.info(
              "Skipping file: couldn't create CGImage",
              metadata: [
                "fileURL": "\(fileURL)"
              ]
            )
            return []
          }
          guard let relativePath = fileURL.deletingPathExtension().path(relativeTo: parentPath)
          else {
            Self.logger.info(
              "Skipping file: couldn't compute relative path",
              metadata: [
                "fileURL": "\(fileURL)",
                "parentPath": "\(parentPath)"
              ]
            )
            return []
          }
          return [.image(image: cgImage, path: relativePath, size: imageRect.size)]
        }
      }

      var array = [PDFItem]()
      for try await images in group {
        array.append(contentsOf: images)
      }
      return array.sorted(by: { $0.path < $1.path })
    }
  }

  @PDFActor
  private func writePDF(images: [PDFItem], to output: URL) throws {
    let document = assembleDocument(from: images)
    guard document.write(to: output) else { throw Errors.couldntWritePDF(url: output) }
  }

  @PDFActor
  private func assembleDocument(from images: [PDFItem]) -> PDFDocument {
    let document = PDFDocument()
    let tocRoot = buildTOC(documentTitle: title, images: images)
    var sourceDocuments: [URL: PDFDocument] = [:]
    var insertionIndex = 0

    for item in images {
      guard let page = page(for: item, sourceDocuments: &sourceDocuments) else { continue }
      document.insert(page, at: insertionIndex)
      insertionIndex += 1
      var titlePath = item.path.split(separator: "/").map(String.init)
      tocRoot.setPage(page, for: &titlePath)
    }

    document.outlineRoot = tocRoot.outline
    return document
  }

  @PDFActor
  private func page(for item: PDFItem, sourceDocuments: inout [URL: PDFDocument]) -> PDFPage? {
    switch item {
      case let .image(cgImage, _, size):
        return PDFPage(
          image: NSImage(cgImage: cgImage, size: size),
          options: [
            .compressionQuality: Self.imageCompressionQuality,
            .mediaBox: CGRect(origin: .zero, size: pageSize),
            .upscaleIfSmaller: true
          ]
        )
      case let .pdfPage(sourceURL, pageIndex, _):
        return sourceDocument(at: sourceURL, cache: &sourceDocuments)?.page(at: pageIndex)
    }
  }

  @PDFActor
  private func sourceDocument(at url: URL, cache: inout [URL: PDFDocument]) -> PDFDocument? {
    if let cached = cache[url] { return cached }
    guard let document = PDFDocument(url: url) else { return nil }
    cache[url] = document
    return document
  }

  @PDFActor
  private func buildTOC(documentTitle: String, images: [PDFItem]) -> TOCNode {
    let root = TOCNode(title: documentTitle)
    for image in images {
      var titlePath = image.path.split(separator: "/").map(String.init)
      root.addChildren(titlePath: &titlePath)
    }
    return root
  }
}
