import Foundation
import SwiftUI

extension PocketBaseNote {
    var noteColor: Color {
        if let color = color, !color.isEmpty {
            return NoteColor.fromString(color)
        }
        return .purple  // Default color
    }
    
    var date: Date {
        // Convex stores `created` as epoch-ms (Double).
        guard let ms = created else { return Date() }
        return Date(timeIntervalSince1970: ms / 1000)
    }
    
    var formattedDate: String {
        let dateFormatter = RelativeDateTimeFormatter()
        dateFormatter.dateTimeStyle = .named
        return dateFormatter.localizedString(for: date, relativeTo: Date())
    }
    
    var detailedDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: date)
    }
}

enum NoteColor: String, CaseIterable, Codable {
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        }
    }
    
    static func fromString(_ colorString: String) -> Color {
        if let noteColor = NoteColor(rawValue: colorString.lowercased()) {
            return noteColor.color
        }
        return .purple  // Default color
    }
}