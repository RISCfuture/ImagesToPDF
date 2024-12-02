import Foundation
import CoreGraphics

extension URL {
    func path(relativeTo prefix: String) -> String? {
        guard isFileURL,
              path.hasPrefix(prefix) else { return nil }
        
        let relativePath = String(path.dropFirst(prefix.count))
        return relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
    }
}

func *(lhs: CGSize, rhs: CGFloat) -> CGSize {
    .init(width: lhs.width * rhs, height: lhs.height * rhs)
}

extension CGSize {
    var aspectRatio: CGFloat { width / height }
    
    func fit(within bounds: CGSize) -> CGSize {
        if aspectRatio > bounds.aspectRatio {
            // I am wider than the bounds; scale my width to bounds width
            return .init(width: bounds.width, height: bounds.width / aspectRatio)
        } else {
            // I am taller than the bounds; scale my height to bounds height
            return .init(width: bounds.height * aspectRatio, height: bounds.height)
        }
    }
    
    func center(within bounds: CGSize) -> CGRect {
        let origin = CGPoint(x: (bounds.width - width) / 2,
                             y: (bounds.height - height) / 2)
        return .init(origin: origin, size: fit(within: bounds))
    }
}

extension CGImage {
    var size: CGSize { .init(width: width, height: height) }
}
