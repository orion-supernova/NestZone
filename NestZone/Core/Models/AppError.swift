import Foundation

/// Every failure the UI can be asked to show.
///
/// Screens used to surface `error.localizedDescription` straight from Convex,
/// which produced strings like "The data couldn't be read because it isn't in
/// the correct format" in front of users. Mapping to a closed set lets the UI
/// say something true and actionable, and lets tests assert on a case.
public enum AppError: Error, Equatable, Sendable {
    /// No home is selected, so a home-scoped call cannot be made.
    case noHomeSelected
    /// The session expired or was never established.
    case notAuthenticated
    /// The device is offline or the socket is down.
    case offline
    /// The server rejected the request.
    case server(String)
    /// The payload did not match what the client expected.
    case decoding(String)
    /// Local validation failed before anything was sent.
    case validation(String)
    case cancelled
    case unknown(String)

    public init(_ error: any Error) {
        switch error {
        case let appError as AppError:
            self = appError
        case is CancellationError:
            self = .cancelled
        case let urlError as URLError:
            self = switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: .offline
            case .cancelled: .cancelled
            default: .server(urlError.localizedDescription)
            }
        case let decodingError as DecodingError:
            self = .decoding(String(describing: decodingError))
        default:
            self = .unknown(error.localizedDescription)
        }
    }
}

extension AppError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noHomeSelected:
            String(localized: "error.noHomeSelected", defaultValue: "Pick a home first.")
        case .notAuthenticated:
            String(localized: "error.notAuthenticated", defaultValue: "You've been signed out. Sign in to continue.")
        case .offline:
            String(localized: "error.offline", defaultValue: "You're offline. We'll retry when you're back.")
        case .server:
            String(localized: "error.server", defaultValue: "Something went wrong on our end. Try again.")
        case .decoding:
            String(localized: "error.decoding", defaultValue: "We couldn't read that response. Try again.")
        case let .validation(message):
            message
        case .cancelled:
            nil
        case .unknown:
            String(localized: "error.unknown", defaultValue: "Something went wrong. Try again.")
        }
    }

    /// Detail for the log, never for the user.
    public var diagnostic: String {
        switch self {
        case .noHomeSelected: "noHomeSelected"
        case .notAuthenticated: "notAuthenticated"
        case .offline: "offline"
        case let .server(m): "server: \(m)"
        case let .decoding(m): "decoding: \(m)"
        case let .validation(m): "validation: \(m)"
        case .cancelled: "cancelled"
        case let .unknown(m): "unknown: \(m)"
        }
    }

    /// Cancellation is bookkeeping, not something to show anyone.
    public var isSilent: Bool { self == .cancelled }
}
