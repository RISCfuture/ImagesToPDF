import PDFKit

/// A node in the table of contents tree for the generated PDF.
@PDFActor
final class TOCNode {
  let title: String
  var page: PDFPage?

  var children: [TOCNode] = []

  // The PDFKit outline subtree rooted at this node, or nil if no page has been assigned.
  var outline: PDFOutline? {
    guard let page else { return nil }
    let outline = PDFOutline()
    outline.label = title
    outline.destination = .init(
      page: page,
      at: .init(x: 0, y: page.bounds(for: .mediaBox).height)
    )
    for (index, child) in children.sorted(by: { $0.title < $1.title }).enumerated() {
      guard let childOutline = child.outline else { return nil }
      outline.insertChild(childOutline, at: index)
    }
    return outline
  }

  init(title: String) {
    self.title = title
  }

  func setPage(_ page: PDFPage, for path: inout [String]) {
    guard !path.isEmpty else {
      self.page = page
      return
    }
    let title = path.removeFirst()
    guard let child = children.first(where: { $0.title == title }) else { return }
    child.setPage(page, for: &path)
    if children.first === child {
      self.page = page
    }
  }

  func addChildren(titlePath: inout [String]) {
    guard !titlePath.isEmpty else { return }
    let nextTitle = titlePath.removeFirst()
    let nextNode: TOCNode
    if let existing = children.first(where: { $0.title == nextTitle }) {
      nextNode = existing
    } else {
      let newNode = TOCNode(title: nextTitle)
      children.append(newNode)
      nextNode = newNode
    }
    nextNode.addChildren(titlePath: &titlePath)
  }
}
