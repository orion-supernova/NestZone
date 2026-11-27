import Foundation
import SwiftUI

/// The join link of a meeting, and the service it belongs to.
///
/// People paste whatever the invitation gave them, so the link is trimmed and
/// a missing scheme is added; only http and https count, so a `tel:` or a
/// `javascript:` typed into the field never gets a Join button.
public struct MeetingLink: Equatable, Sendable {
    public enum Service: Equatable, Sendable {
        case meet, zoom, teams, faceTime, webex, other

        /// Brand names are not translated.
        public var brandName: String? {
            switch self {
            case .meet: "Google Meet"
            case .zoom: "Zoom"
            case .teams: "Microsoft Teams"
            case .faceTime: "FaceTime"
            case .webex: "Webex"
            case .other: nil
            }
        }

        public var name: Text {
            if let brandName { Text(verbatim: brandName) } else { Text(L10n.meetingServiceOther) }
        }
    }

    public let url: URL
    public let service: Service

    public init?(_ raw: String?) {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: withScheme),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host?.lowercased(), host.contains(".") else { return nil }
        self.url = url
        self.service = Self.service(forHost: host)
    }

    static func service(forHost host: String) -> Service {
        func isHost(_ domain: String) -> Bool { host == domain || host.hasSuffix("." + domain) }
        if host == "meet.google.com" { return .meet }
        if isHost("zoom.us") { return .zoom }
        if host == "teams.microsoft.com" || host == "teams.live.com" { return .teams }
        if host == "facetime.apple.com" { return .faceTime }
        if isHost("webex.com") { return .webex }
        return .other
    }

    /// The first link in a piece of pasted text, which may be a whole
    /// invitation. Nil when there is none.
    public static func firstLink(in text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        let match = detector?.firstMatch(in: text, options: [], range: range)
        guard let url = match?.url, let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url.absoluteString
    }

    /// How early a meeting starts offering its Join button.
    public static let joinLead: TimeInterval = 10 * 60
}

extension EventOccurrence {
    /// A meeting's link, when it is a meeting and the link is one.
    public var meetingLink: MeetingLink? {
        kind == .meeting ? MeetingLink(url) : nil
    }

    /// From ten minutes before the start until the end.
    public func canJoin(at now: Date) -> Bool {
        guard meetingLink != nil, !isAllDay else { return false }
        return now >= start.addingTimeInterval(-MeetingLink.joinLead) && now < end
    }
}
