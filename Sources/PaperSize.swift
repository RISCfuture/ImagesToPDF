import ArgumentParser
import CoreGraphics

/// Standard paper sizes with their dimensions in points (1/72 inch).
enum PaperSize: String, CaseIterable, ExpressibleByArgument {
  // ISO A series
  case A2 = "a2"
  case A4 = "a4"
  case A5 = "a5"
  case A6 = "a6"
  case A7 = "a7"
  case A8 = "a8"
  case A9 = "a9"

  // ISO B series
  case B0 = "b0"
  case B1 = "b1"
  case B2 = "b2"
  case B3 = "b3"
  case B4 = "b4"
  case B5 = "b5"
  case B6 = "b6"
  case B7 = "b7"
  case B8 = "b8"
  case B9 = "b9"
  case B10 = "b10"
  case B1Plus = "b1+"
  case B2Plus = "b2+"

  // ISO C series (envelope sizes)
  case C0 = "c0"
  case C1 = "c1"
  case C2 = "c2"
  case C3 = "c3"
  case C4 = "c4"
  case C5 = "c5"
  case C6 = "c6"
  case C7 = "c7"
  case C8 = "c8"
  case C9 = "c9"
  case C10 = "c10"

  // North American sizes
  case Letter = "letter"
  case Legal = "legal"
  case Tabloid = "tabloid"
  case Ledger = "ledger"
  case JuniorLegal = "junior-legal"
  case GovernmentLetter = "government-letter"

  // ANSI sizes
  case ANSI_A = "ansi-a"
  case ANSI_B = "ansi-b"
  case ANSI_C = "ansi-c"
  case ANSI_D = "ansi-d"
  case ANSI_E = "ansi-e"

  /// The dimensions of this paper size in points.
  var dimensions: CGSize {
    let (width, height) = dimensionsTuple
    return CGSize(width: width, height: height)
  }

  private var dimensionsTuple: (Int, Int) {
    switch self {
      // ISO A series
      case .A2: (1191, 1684)
      case .A4: (595, 842)
      case .A5: (420, 595)
      case .A6: (298, 420)
      case .A7: (210, 298)
      case .A8: (147, 210)
      case .A9: (105, 147)

      // ISO B series
      case .B0: (4008, 2835)
      case .B1: (2835, 2004)
      case .B2: (2004, 1417)
      case .B3: (1417, 1001)
      case .B4: (1001, 709)
      case .B5: (709, 499)
      case .B6: (499, 354)
      case .B7: (354, 249)
      case .B8: (249, 176)
      case .B9: (176, 125)
      case .B10: (125, 88)
      case .B1Plus: (2891, 2041)
      case .B2Plus: (2041, 1474)

      // ISO C series
      case .C0: (3677, 2599)
      case .C1: (2599, 1837)
      case .C2: (1837, 1298)
      case .C3: (1298, 918)
      case .C4: (918, 649)
      case .C5: (649, 459)
      case .C6: (459, 323)
      case .C7: (323, 230)
      case .C8: (230, 162)
      case .C9: (162, 113)
      case .C10: (113, 79)

      // North American sizes
      case .Letter: (612, 791)
      case .Legal: (612, 1009)
      case .Tabloid: (791, 1225)
      case .Ledger: (1225, 791)
      case .JuniorLegal: (360, 575)
      case .GovernmentLetter: (576, 756)

      // ANSI sizes
      case .ANSI_A: (612, 791)
      case .ANSI_B: (791, 1225)
      case .ANSI_C: (1225, 1585)
      case .ANSI_D: (1585, 2449)
      case .ANSI_E: (2449, 3169)
    }
  }

  /// Parses a size string that can be either a paper size name or dimensions like "1191x1684".
  static func parse(_ string: String) -> CGSize? {
    if let size = Self(rawValue: string.lowercased()) {
      return size.dimensions
    }

    let parts = string.split(separator: "x")
    guard parts.count == 2,
      let width = Int(parts[0]),
      let height = Int(parts[1])
    else {
      return nil
    }

    return CGSize(width: width, height: height)
  }
}
