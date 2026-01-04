@preconcurrency import PDFKit

/// A node in the table of contents tree for the generated PDF.
final actor TOCNode: Equatable {
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
      outline.destination = .init(
        page: page,
        at: .init(x: 0, y: page.bounds(for: .mediaBox).height)
      )
      for (index, child) in children.sorted(by: { $0.title < $1.title }).enumerated() {
        guard let childOutline = await child.outline else { return nil }
        outline.insertChild(childOutline, at: index)
      }
      return outline
    }
  }

  init(title: String, parent: TOCNode? = nil) {
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
    let nextNode: TOCNode
    if let existing = children.first(where: { $0.title == nextTitle }) {
      nextNode = existing
    } else {
      let newNode = TOCNode(title: nextTitle, parent: self)
      children.append(newNode)
      nextNode = newNode
    }
    await nextNode.addChildren(titlePath: &titlePath)
  }
}
