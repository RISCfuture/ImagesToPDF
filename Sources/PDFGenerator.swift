import Foundation
import Logging
@preconcurrency import PDFKit

private func loadPDFPages(from fileURL: URL, parentPath: String, pageSize _: CGSize) -> [PDFGenerator.PDFItem] {
    let logger = Logger(label: "codes.tim.ImagesToPDF.PDFGenerator")
    guard let pdfDocument = PDFDocument(url: fileURL) else {
        logger.info("Skipping PDF: couldn't create PDFDocument", metadata: [
            "fileURL": "\(fileURL)"
        ])
        return []
    }

    let relativePath = fileURL.deletingPathExtension().path(relativeTo: parentPath)!
    var results: [PDFGenerator.PDFItem] = []

    for pageIndex in 0..<pdfDocument.pageCount {
        guard let page = pdfDocument.page(at: pageIndex) else { continue }

        let pagePath = pageIndex == 0 ? relativePath : "\(relativePath)/Page \(pageIndex + 1)"
        results.append(.pdfPage(page: page, path: pagePath))
    }

    return results
}

class PDFGenerator {
    private static let logger = Logger(label: "codes.tim.ImagesToPDF.PDFGenerator")

    private let input: URL
    private let title: String
    private let pageSize: CGSize

    var allowedSuffixes = [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".pdf"]

    private var pageRect: CGRect { .init(origin: .zero, size: pageSize) }

    init(input: URL, title: String, pageSize: CGSize) {
        self.input = input
        self.title = title
        self.pageSize = pageSize
    }

    func generate(to output: URL) async throws {
        let images = try await loadImages()
        let pdf = await generatePDF(images: images, pageSize: pageSize)
        guard pdf.write(to: output) else { throw Errors.couldntWritePDF(url: output) }
    }

    private func loadImages() async throws -> [PDFItem] {
        let allowedSuffixes = self.allowedSuffixes,
            parentPath = self.input.path(percentEncoded: false),
            pageSize = self.pageSize

        return try await withThrowingTaskGroup(of: [PDFItem].self) { group in
            let enumerator = FileManager.default.enumerator(at: input, includingPropertiesForKeys: [.isRegularFileKey, .nameKey, .pathKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])!
            let allURLs = enumerator.compactMap { $0 as? URL }
            for fileURL in allURLs {
                group.addTask { () -> [PDFItem] in
                    guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .nameKey, .pathKey]),
                          let isRegularFile = resourceValues.isRegularFile,
                          let name = resourceValues.name,
                          let path = resourceValues.path else {
                        Self.logger.info("Skipping file: couldn’t load resource values", metadata: [
                            "fileURL": "\(fileURL)"
                        ])
                        return []
                    }
                    guard isRegularFile else { return [] }
                    guard allowedSuffixes.contains(where: { name.hasSuffix($0) }) else {
                        Self.logger.info("Skipping file: not an image or PDF file", metadata: [
                            "path": "\(path)"
                        ])
                        return []
                    }

                    if name.hasSuffix(".pdf") {
                        return loadPDFPages(from: fileURL, parentPath: parentPath, pageSize: pageSize)
                    }

                    guard let nsImage = NSImage(contentsOfFile: path) else {
                        Self.logger.info("Skipping file: couldn’t create NSImage", metadata: [
                            "fileURL": "\(fileURL)"
                        ])
                        return []
                    }
                    var imageRect = CGRect(origin: .zero, size: nsImage.size)
                    guard let cgImage = nsImage.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) else {
                        Self.logger.info("Skipping file: couldn’t create CGImage", metadata: [
                            "fileURL": "\(fileURL)"
                        ])
                        return []
                    }
                    let relativePath = fileURL.deletingPathExtension().path(relativeTo: parentPath)!
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
        await withTaskGroup(of: (page: PDFPage?, index: Int).self) { group in
            let document = PDFDocument()

            for (index, item) in images.enumerated() {
                group.addTask {
                    let page: PDFPage?

                    switch item {
                        case let .image(cgImage, _, size):
                            page = PDFPage(image: NSImage(cgImage: cgImage, size: size),
                                           options: [.compressionQuality: 0.9,
                                                     .mediaBox: CGRect(origin: .zero, size: pageSize),
                                                     .upscaleIfSmaller: true])
                        case let .pdfPage(pdfPage, _):
                            page = pdfPage
                    }

                    return (page: page, index: index)
                }
            }

            let pages = await group.filter({ $0.page != nil })
                .reduce(into: []) { array, element in array.append(element) }
                .sorted(by: { $0.index < $1.index })

            let TOCRoot = await buildTOC(documentTitle: title, images: images)
            for (index, page) in pages.enumerated() {
                document.insert(page.page!, at: index)
                var titlePath = images[index].path.split(separator: "/").map { String($0) }
                await TOCRoot.setPage(page.page!, for: &titlePath)
            }

            document.outlineRoot = await TOCRoot.outline
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

    private final actor TOCNode: Equatable {
        let title: String
        var page: PDFPage?

        var children: [TOCNode] = []
        private weak var parent: TOCNode?

        var level: Int {
            get async {
                guard let parent else { return 0 }
                return await parent.level + 1
            }
        }

        var index: Int? {
            get async {
                guard let parent else { return nil }
                return await parent.children.firstIndex(of: self)
            }
        }

        var outline: PDFOutline? {
            get async {
                guard let page else { return nil }
                let outline = PDFOutline()
                outline.label = title
                outline.destination = .init(page: page, at: .init(x: 0, y: page.bounds(for: .mediaBox).height))
                for (index, child) in children.sorted(by: { $0.title < $1.title }).enumerated() {
                    guard let childOutline = await child.outline else { return nil }
                    outline.insertChild(childOutline, at: index)
                }
                return outline
            }
        }

        init(title: String, parent: TOCNode? = nil, page _: PDFPage? = nil) {
            self.title = title
            self.parent = parent
        }

        static func == (lhs: TOCNode, rhs: TOCNode) -> Bool {
            lhs.title == rhs.title
        }

        func setPage(_ page: PDFPage, for path: inout [String]) async {
            guard !path.isEmpty else {
                self.page = page
                return
            }
            let title = path.removeFirst()
            guard let child = children.first(where: { $0.title == title }) else { return }
            await child.setPage(page, for: &path)
            if children.firstIndex(of: child) == 0 {
                self.page = page
            }
        }

        func addChildren(titlePath: inout [String]) async {
            guard !titlePath.isEmpty else { return }
            let nextTitle = titlePath.removeFirst()
            var nextNode = children.first(where: { $0.title == nextTitle })
            if nextNode == nil {
                children.append(.init(title: nextTitle, parent: self))
                nextNode = children.last
            }
            await nextNode!.addChildren(titlePath: &titlePath)
        }
    }
}
