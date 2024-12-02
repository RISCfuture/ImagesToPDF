import Foundation

enum Errors: Error {
    case couldntWritePDF(url: URL)
}

extension Errors: LocalizedError {
    var description: String {
        switch self {
            case let .couldntWritePDF(url):
                return "Couldn’t create PDF file at “\(url.path)”"
        }
    }
}
