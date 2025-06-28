import ArgumentParser
import Foundation

@main
struct ImagesToPDF: AsyncParsableCommand {
    static let configuration: CommandConfiguration = .init(
        abstract: "Converts a nested directory structure of images to a PDF file with Table of Contents.",
        discussion: """
            This command-line tool was originally intended to be used with the instrument
            procedure plates that come with Falcon BMS campaign documentation, but can
            easily be used with any collection of images.

            The generated Table of Contents is saved as a PDF outline, and will appear using
            any PDF viewer’s Outline feature.
            """
    )

    private static var letterSize: CGSize {
        let (w, h) = PAPER_SIZES["letter"]!
        return .init(width: w, height: h)
    }

    @Argument(
        help: "The input directory containing the image files.",
        completion: .directory,
        transform: { URL(filePath: $0, directoryHint: .isDirectory) })
    var input: URL = .currentDirectory()

    @Argument(
        help: "The PDF file to generate.",
        completion: .file(extensions: ["pdf]"]),
        transform: { URL(filePath: $0, directoryHint: .notDirectory) }
    )
    var output: URL

    @Option(
        name: .shortAndLong,
        help: "The title of the Table of Contents for the generated PDF. (default: file name)")
    var title: String?

    @Option(
        name: [.customShort("s"), .customLong("size")],
        help: "The page size of the resulting PDF. Can be a name (e.g. ‘a2’) or a width and height in points (e.g. ‘1191x1684’). (default: letter)",
        transform: { Self.size(from: $0) })
    var pageSize: CGSize?

    private static func size(from name: String) -> CGSize? {
        if let (w, h) = PAPER_SIZES[name.lowercased()] {
            return .init(width: w, height: h)
        }

        let parts = name.split(separator: "x")
        guard parts.count == 2 else { return nil }
        guard let w = Int(parts[0]), let h = Int(parts[1]) else { return nil }

        return .init(width: w, height: h)
    }

    mutating func run() async throws {
        let title = self.title ?? input.deletingPathExtension().lastPathComponent
        let size = self.pageSize ?? Self.letterSize

        let generator = PDFGenerator(input: input, title: title, pageSize: size)
        try await generator.generate(to: output)
    }
}

private let PAPER_SIZES = [
    "a2": (1191, 1684),
    "a5": (420, 595),
    "a4": (595, 842),
    "a7": (210, 298),
    "a6": (298, 420),
    "a9": (105, 147),
    "a8": (147, 210),
    "b10": (125, 88),
    "b1+": (2891, 2041),
    "b4": (1001, 709),
    "b5": (709, 499),
    "b6": (499, 354),
    "b7": (354, 249),
    "b0": (4008, 2835),
    "b1": (2835, 2004),
    "b2": (2004, 1417),
    "b3": (1417, 1001),
    "b2+": (2041, 1474),
    "b8": (249, 176),
    "b9": (176, 125),
    "c10": (113, 79),
    "c9": (162, 113),
    "c8": (230, 162),
    "c3": (1298, 918),
    "c2": (1837, 1298),
    "c1": (2599, 1837),
    "c0": (3677, 2599),
    "c7": (323, 230),
    "c6": (459, 323),
    "c5": (649, 459),
    "c4": (918, 649),
    "legal": (612, 1009),
    "junior-legal": (360, 575),
    "government-letter": (576, 756),
    "letter": (612, 791),
    "tabloid": (791, 1225),
    "ledger": (1225, 791),
    "ansi-c": (1225, 1585),
    "ansi-a": (612, 791),
    "ansi-b": (791, 1225),
    "ansi-e": (2449, 3169),
    "ansi-d": (1585, 2449)
]
