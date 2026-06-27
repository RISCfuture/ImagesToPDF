// Serializes all access to PDFKit's PDFDocument, PDFPage, and PDFOutline, which are not
// thread-safe, by confining them to a single isolation domain so they never cross a
// concurrency boundary.
@globalActor
actor PDFActor {
  static let shared = PDFActor()
}
