import Foundation

/// Where this device stands with APNs *and* with our server.
///
/// These are two different facts and the Settings panel used to conflate them
/// into one `String?`, which is how it came to call every device unregistered
/// while push worked perfectly. A token this device holds is not a token the
/// server can reach it with: iOS hands one over long before the registering
/// mutation lands, and that mutation can fail on its own.
///
/// Three questions are asked of this, and each gets its own answer:
///
/// - *Can a push land on this phone?* — only `registered`. That is what the
///   "This device" row reports, so the row is never more confident than the
///   truth.
/// - *Is there anything to register?* — any case carrying a token.
/// - *What must sign-out unregister?* — `token`, in **any** state. A failed
///   registration this launch does not mean the server has no row: an earlier
///   launch may well have registered the same token, and a sign-out that
///   skipped it would leave the device in a household it has left.
public enum PushRegistration: Equatable, Sendable {
    /// iOS has not handed a token over — never asked, still in flight, or it
    /// refused. Nothing can reach this device either way.
    case none
    /// We hold a token; the server has not accepted it yet.
    case pending(token: String)
    /// The server holds this token. The only state that means reachable.
    case registered(token: String)
    /// We hold a token the server would not take, after every retry.
    case failed(token: String)

    /// The token this device holds, whatever the server made of it.
    ///
    /// Sign-out unregisters this rather than only a confirmed one — see the
    /// note above.
    public var token: String? {
        switch self {
        case .none: nil
        case let .pending(token), let .registered(token), let .failed(token): token
        }
    }

    /// Whether the server can actually push here.
    public var isRegistered: Bool {
        if case .registered = self { return true }
        return false
    }
}
