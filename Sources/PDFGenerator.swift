import Foundation
@preconcurrency import PDFKit
import Logging

class PDFGenerator {
    private let input: URL
    private let title: String
    private let pageSize: CGSize
    
    var allowedSuffixes = [".png", ".jpg", ".jpeg", ".gif", ".bmp"]
    
    private var pageRect: CGRect { .init(origin: .zero, size: pageSize) }
    
    private static let logger = Logger(label: "codes.tim.ImagesToPDF.PDFGenerator")
    
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
    
    private func loadImages() async throws -> [PDFImage] {
        let allowedSuffixes = self.allowedSuffixes,
            parentPath = self.input.path(percentEncoded: false)
        
        return try await withThrowingTaskGroup(of: PDFImage?.self) { group in
            let enumerator = FileManager.default.enumerator(at: input, includingPropertiesForKeys: [.isRegularFileKey, .nameKey, .pathKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])!
            for case let fileURL as URL in enumerator {
                group.addTask { () -> PDFImage? in
                    guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .nameKey, .pathKey]),
                          let isRegularFile = resourceValues.isRegularFile,
                          let name = resourceValues.name,
                          let path = resourceValues.path else {
                        Self.logger.info("Skipping file: couldn’t load resource values", metadata: [
                            "fileURL": "\(fileURL)"
                        ])
                        return nil
                    }
                    guard isRegularFile else { return nil }
                    guard allowedSuffixes.contains(where: { name.hasSuffix($0) }) else {
                        Self.logger.info("Skipping file: not an image file", metadata: [
                            "path": "\(path)"
                        ])
                        return nil
                    }
                    
                    guard let nsImage = NSImage(contentsOfFile: path) else {
                        Self.logger.info("Skipping file: couldn’t create NSImage", metadata: [
                            "fileURL": "\(fileURL)"
                        ])
                        return nil
                    }
                    var imageRect = CGRect(origin: .zero, size: nsImage.size)
                    guard let cgImage = nsImage.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) else {
                        Self.logger.info("Skipping file: couldn’t create CGImage", metadata: [
                            "fileURL": "\(fileURL)"
                        ])
                        return nil
                    }
                    let relativePath = fileURL.deletingPathExtension().path(relativeTo: parentPath)!
                    return .init(image: cgImage, path: relativePath, size: imageRect.size)
                }
            }
            
            var array = [PDFImage]()
            for try await image in group {
                guard let image else { continue }
                array.append(image)
            }
            return array.sorted(by: { $0.path < $1.path })
        }
    }
    
    private func generatePDF(images: [PDFImage], pageSize: CGSize) async -> PDFDocument {
        await withTaskGroup(of: (page: PDFPage?, index: Int).self) { group in
            let document = PDFDocument()
            
            for (index, image) in images.enumerated() {
                group.addTask {
                    let page = PDFPage(image: NSImage(cgImage: image.image, size: image.size),
                                       options: [.compressionQuality: 0.9,
                                                 .mediaBox: CGRect(origin: .zero, size: pageSize),
                                                 .upscaleIfSmaller: true])
                    
                    return (page: page, index: index)
                }
            }
            
            let pages = await group.filter({ $0.page != nil }).reduce(into: []) { array, element in array.append(element) }
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
    
    private func buildTOC(documentTitle: String, images: [PDFImage]) async -> TOCNode {
        let root = TOCNode(title: documentTitle)
        for image in images {
            var titlePath = image.path.split(separator: "/").map { String($0) }
            await root.addChildren(titlePath: &titlePath)
        }
        return root
    }
    
    private struct PDFImage: Sendable, Equatable, Hashable {
        let image: CGImage
        let path: String
        let size: NSSize
        
        static func == (lhs: PDFImage, rhs: PDFImage) -> Bool {
            lhs.path == rhs.path
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(path)
        }
        
        var nsImage: NSImage {
            .init(cgImage: image, size: size)
        }
    }
    
    private final actor TOCNode: Sendable, Equatable {
        let title: String
        var page: PDFPage?
        
        var children: [TOCNode] = []
        weak private var parent: TOCNode?
        
        init(title: String, parent: TOCNode? = nil, page: PDFPage? = nil) {
            self.title = title
            self.parent = parent
        }
        
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
        
        static func == (lhs: TOCNode, rhs: TOCNode) -> Bool {
            lhs.title == rhs.title
        }
    }
}
