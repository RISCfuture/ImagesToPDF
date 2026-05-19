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
