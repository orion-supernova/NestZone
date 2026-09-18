import ComposableArchitecture
import ConvexMobile
import Foundation

/// Registers this device's APNs token with the backend.
@DependencyClient
public struct DevicesClient: Sendable {
    public var register: @Sendable (_ token: String, _ environment: String) async throws -> Void
    public var unregister: @Sendable (_ token: String) async throws -> Void
    /// Sends a push to the caller's own devices, to prove the chain works.
    ///
    /// Returns what APNs made of it. A call that throws and a call that returns
    /// `sent: 0` are both failures from the tapping user's point of view, and
    /// only the count can tell the second one apart from success.
    public var sendTestToSelf: @Sendable () async throws -> PushResult
}

extension DevicesClient: DependencyKey {
    public static let liveValue = DevicesClient(
        register: { token, environment in
            try await ConvexConnection.shared.mutate(
                "push:registerDevice",
                args: [
                    "token": token,
                    "environment": environment,
                    // Free: registration already happens once per launch, so
                    // this rides along rather than costing a call of its own.
                    // It is the only thing that tells the backend which builds
                    // are still in the wild, which is what makes retiring
                    // anything safe — see backend/DEPRECATIONS.md.
                    "appVersion": AppVersion.current.raw,
                ]
            )
        },
        unregister: { token in
            try await ConvexConnection.shared.mutate(
                "push:unregisterDevice", args: ["token": token]
            )
        },
        sendTestToSelf: {
            try await ConvexConnection.shared.act(
                "push:sendTestToSelf", as: PushResult.self
            )
        }
    )

    public static let testValue = DevicesClient()
}

/// What the server made of one fan-out: how many devices APNs accepted, and how
/// many tokens it rejected as dead and the server therefore deleted.
public struct PushResult: Decodable, Sendable, Equatable {
    public let sent: Int
    public let dropped: Int

    public init(sent: Int, dropped: Int) {
        self.sent = sent
        self.dropped = dropped
    }
}

extension DependencyValues {
    public var devices: DevicesClient {
        get { self[DevicesClient.self] }
        set { self[DevicesClient.self] = newValue }
    }
}

/// Which APNs gateway this build's tokens belong to.
///
/// A token minted against the sandbox gateway is rejected by production and vice
/// versa, so the environment travels with the token.
///
/// What decides it is the `aps-environment` entitlement in the provisioning
/// profile, and only a development profile carries `development`. TestFlight is
/// signed with an App Store distribution profile like any other release, so its
/// tokens are **production** tokens.
///
/// This used to answer "sandbox" for TestFlight, on the strength of its receipt
/// being named `sandboxReceipt` — but that is StoreKit's sandbox, not APNs's,
/// and the two have nothing to do with each other. Every push to a TestFlight
/// build was posted to the wrong gateway, came back `BadDeviceToken`, and took
/// the device's token down with it. The server double-checks the answer now
/// rather than trusting it, so a wrong guess here degrades to one wasted
/// request instead of a silently unreachable phone.
public enum APNSEnvironment {
    public static var current: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }
}
