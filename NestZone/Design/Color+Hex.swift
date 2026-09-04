import SwiftUI

extension Color {
    /// Builds a colour from `RRGGBB` / `#RRGGBB` / `RRGGBBAA`.
    ///
    /// Deliberately cheap, but still not free — every call parses a string. Use
    /// it only to define `static let` constants, never inside a `body`. The old
    /// theme layer called this ~40 times per screen redraw.
    public init(hex: String) {
        let raw = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)

        let r, g, b, a: Double
        switch raw.count {
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
