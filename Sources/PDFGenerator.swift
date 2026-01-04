import Foundation
import Logging
@preconcurrency import PDFKit

// Mark PDFKit types as Sendable for Swift 6 concurrency
// These are safe in this context as we control all access patterns
extension PDFOutline: @retroactive @unchecked Sendable {}
extension PDFPage: @retroactive @unchecked Sendable {}

private func loadPDFPages(from fileURL: URL, parentPath: String, logger: Logger) -> [PDFItem] {
  guard let pdfDocument = PDFDocument(url: fileURL) else {
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
  var results: [PDFItem] = []

  for pageIndex in 0..<pdfDocument.pageCount {
    guard let page = pdfDocument.page(at: pageIndex) else { continue }

    let pagePath = pageIndex == 0 ? relativePath : "\(relativePath)/Page \(pageIndex + 1)"
    results.append(.pdfPage(page: page, path: pagePath))
  }

  return results
}

/// Generates PDF documents from a directory of images and existing PDFs.
///
/// The generator recursively scans the input directory for supported image formats
/// and PDF files, combining them into a single PDF with a table of contents based
/// on the directory structure.
class PDFGenerator {
  private static let logger = Logger(label: "codes.tim.ImagesToPDF.PDFGenerator")

  private let input: URL
  private let title: String
  private let pageSize: CGSize

  /// File extensions that will be included in the generated PDF.
  var allowedSuffixes = [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".pdf"]

  private var pageRect: CGRect { .init(origin: .zero, size: pageSize) }

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
    let pdf = await generatePDF(images: images, pageSize: pageSize)
    guard pdf.write(to: output) else { throw Errors.couldntWritePDF(url: output) }
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
            return loadPDFPages(from: fileURL, parentPath: parentPath, logger: Self.logger)
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

  private func generatePDF(images: [PDFItem], pageSize: CGSize) async -> PDFDocument {
    await withTaskGroup(of: PageResult.self) { group in
      let document = PDFDocument()

      for (index, item) in images.enumerated() {
        group.addTask {
          let page: PDFPage?

          switch item {
            case let .image(cgImage, _, size):
              page = PDFPage(
                image: NSImage(cgImage: cgImage, size: size),
                options: [
                  .compressionQuality: 0.9,
                  .mediaBox: CGRect(origin: .zero, size: pageSize),
                  .upscaleIfSmaller: true
                ]
              )
            case let .pdfPage(pdfPage, _):
              page = pdfPage
          }

          return PageResult(page: page, index: index)
        }
      }

      var pages: [PageResult] = []
      for await result in group {
        guard result.page != nil else { continue }
        pages.append(result)
      }
      pages.sort { $0.index < $1.index }

      let tocRoot = await buildTOC(documentTitle: title, images: images)
      for (index, pageResult) in pages.enumerated() {
        guard let page = pageResult.page else { continue }
        document.insert(page, at: index)
        var titlePath = images[pageResult.index].path.split(separator: "/").map { String($0) }
        await tocRoot.setPage(page, for: &titlePath)
      }

      document.outlineRoot = await tocRoot.outline
      return document
    }
  }

  private func buildTOC(documentTitle: String, images: [PDFItem]) async -> TOCNode {
    let root = TOCNode(title: documentTitle)
    for image in images {
      var titlePath = image.path.split(separator: "/").map { String($0) }
      await root.addChildren(titlePath: &titlePath)
    }
    return root
  }

  // MARK: - Private Types

  /// Wrapper to safely pass PDFPage across concurrency boundaries.
  private struct PageResult: @unchecked Sendable {
    let page: PDFPage?
    let index: Int
  }
}
