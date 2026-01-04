import CoreGraphics
import Foundation

extension URL {
  func path(relativeTo prefix: String) -> String? {
    guard isFileURL,
      let resolvedPrefix = prefix.realPath,
      path.hasPrefix(resolvedPrefix)
    else {
      return nil
    }

    let relativePath = String(path.dropFirst(resolvedPrefix.count))
    return relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
  }
}

extension String {
  fileprivate var realPath: String? {
    var resolved = [CChar](repeating: 0, count: Int(PATH_MAX))
    guard realpath(self, &resolved) != nil else { return nil }
    // Find null terminator and convert to String using failable initializer
    let length = resolved.firstIndex(of: 0) ?? resolved.count
    let bytes = resolved[0..<length].map { UInt8(bitPattern: $0) }
    return String(bytes: bytes, encoding: .utf8)
  }
}

extension CGSize {
  static func * (lhs: Self, rhs: CGFloat) -> Self {
    .init(width: lhs.width * rhs, height: lhs.height * rhs)
  }
}

extension CGSize {
  var aspectRatio: CGFloat { width / height }

  func fit(within bounds: CGSize) -> CGSize {
    if aspectRatio > bounds.aspectRatio {
      // I am wider than the bounds; scale my width to bounds width
      return .init(width: bounds.width, height: bounds.width / aspectRatio)
    }
    // I am taller than the bounds; scale my height to bounds height
    return .init(width: bounds.height * aspectRatio, height: bounds.height)
  }

  func center(within bounds: CGSize) -> CGRect {
    let origin = CGPoint(
      x: (bounds.width - width) / 2,
      y: (bounds.height - height) / 2
    )
    return .init(origin: origin, size: fit(within: bounds))
  }
}

extension CGImage {
  var size: CGSize { .init(width: width, height: height) }
}
