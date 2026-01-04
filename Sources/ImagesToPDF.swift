import ArgumentParser
import Foundation

@main
struct ImagesToPDF: AsyncParsableCommand {
  static let configuration: CommandConfiguration = .init(
    abstract:
      "Converts a nested directory structure of images to a PDF file with Table of Contents.",
    discussion: """
      This command-line tool was originally intended to be used with the instrument
      procedure plates that come with Falcon BMS campaign documentation, but can
      easily be used with any collection of images.

      The generated Table of Contents is saved as a PDF outline, and will appear using
      any PDF viewer’s Outline feature.
      """
  )

  @Argument(
    help: "The input directory containing the image files.",
    completion: .directory,
    transform: { URL(filePath: $0, directoryHint: .isDirectory) }
  )
  var input: URL = .currentDirectory()

  @Argument(
    help: "The PDF file to generate.",
    completion: .file(extensions: ["pdf"]),
    transform: { URL(filePath: $0, directoryHint: .notDirectory) }
  )
  var output: URL

  @Option(
    name: .shortAndLong,
    help: "The title of the Table of Contents for the generated PDF. (default: file name)"
  )
  var title: String?

  @Option(
    name: [.customShort("s"), .customLong("size")],
    help:
      "The page size of the resulting PDF. Can be a name (e.g. ‘a2’) or dimensions in points (e.g. ‘1191x1684’). (default: letter)",
    transform: { PaperSize.parse($0) }
  )
  var pageSize: CGSize?

  mutating func run() async throws {
    let title = self.title ?? input.deletingPathExtension().lastPathComponent
    let size = self.pageSize ?? PaperSize.Letter.dimensions

    let generator = PDFGenerator(input: input, title: title, pageSize: size)
    try await generator.generate(to: output)
  }
}
