import ComposableArchitecture
import ConvexMobile
import Foundation

/// Registers this device's APNs token with the backend.
@DependencyClient
public struct DevicesClient: Sendable {
    public var register: @Sendable (_ token: String, _ environment: String) async throws -> Void
    public var unregister: @Sendable (_ token: String) async throws -> Void
    /// Sends a push to the caller's own devices, to prove the chain works.
    public var sendTestToSelf: @Sendable () async throws -> Void
}

extension DevicesClient: DependencyKey {
    public static let liveValue = DevicesClient(
        register: { token, environment in
            try await ConvexConnection.shared.mutate(
                "push:registerDevice",
                args: ["token": token, "environment": environment]
            )
        },
        unregister: { token in
            try await ConvexConnection.shared.mutate(
                "push:unregisterDevice", args: ["token": token]
            )
        },
        sendTestToSelf: {
            let _: PushResult = try await ConvexConnection.shared.act(
                "push:sendTestToSelf", as: PushResult.self
            )
        }
    )

    public static let testValue = DevicesClient()
}

struct PushResult: Decodable, Sendable {
    let sent: Int
    let dropped: Int
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
