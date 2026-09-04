import ComposableArchitecture
import Foundation
import UIKit
import UserNotifications

/// Notifications, both kinds.
///
/// - **Local**: the cooking timer, which has to fire even when the app is in the
///   background — an in-app countdown stops counting the moment you switch away,
///   which is exactly when a cook needs it most.
/// - **Remote**: household activity, delivered by APNs. The device token is
///   registered against the signed-in user so `convex/push.ts` can fan out to
///   everyone in the home except whoever caused the change.
@DependencyClient
public struct PushClient: Sendable {
    /// Current permission state, without prompting.
    public var authorizationStatus: @Sendable () async -> UNAuthorizationStatus = { .notDetermined }
    /// Prompts if undetermined. Returns whether we ended up authorized.
    public var requestAuthorization: @Sendable () async -> Bool = { false }
    /// Asks iOS for an APNs token. Safe to call repeatedly; the token arrives on
    /// `deviceTokens()`.
    public var registerForRemoteNotifications: @Sendable () async -> Void
    /// Device tokens as they arrive or change. iOS can reissue at any time.
    public var deviceTokens: @Sendable () -> AsyncStream<String> = { .never }

    /// Schedules the cooking timer. Replaces any previous one.
    public var scheduleTimer: @Sendable (_ seconds: Int, _ stepTitle: String) async -> Void
    public var cancelTimer: @Sendable () async -> Void
}

extension PushClient: DependencyKey {
    public static let liveValue: PushClient = {
        PushClient(
            authorizationStatus: {
                await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            },
            requestAuthorization: {
                let center = UNUserNotificationCenter.current()
                let current = await center.notificationSettings().authorizationStatus
                switch current {
                case .authorized, .provisional, .ephemeral:
                    return true
                case .denied:
                    // Only Settings.app can undo this; prompting again is a no-op.
                    return false
                default:
                    return (try? await center.requestAuthorization(
                        options: [.alert, .sound, .badge]
                    )) ?? false
                }
            },
            registerForRemoteNotifications: {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            },
            deviceTokens: { PushTokenBroker.shared.stream() },
            scheduleTimer: { seconds, stepTitle in
                guard seconds > 0 else { return }
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(
                    withIdentifiers: [PushClient.timerIdentifier]
                )
                let content = UNMutableNotificationContent()
                content.title = String(localized: L10n.recipesTimerDoneTitle)
                content.body = stepTitle
                content.sound = .default
                content.interruptionLevel = .timeSensitive

                let request = UNNotificationRequest(
                    identifier: PushClient.timerIdentifier,
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(
                        timeInterval: TimeInterval(seconds),
                        repeats: false
                    )
                )
                try? await center.add(request)
            },
            cancelTimer: {
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(
                    withIdentifiers: [PushClient.timerIdentifier]
                )
                center.removeDeliveredNotifications(
                    withIdentifiers: [PushClient.timerIdentifier]
                )
            }
        )
    }()

    public static let testValue = PushClient()

    /// One id: starting a new timer should replace the old one, never stack.
    static let timerIdentifier = "cooking.timer"
}

extension DependencyValues {
    public var push: PushClient {
        get { self[PushClient.self] }
        set { self[PushClient.self] = newValue }
    }
}

/// Bridges `UIApplicationDelegate`'s token callback into an `AsyncStream`.
///
/// The delegate method is the only way iOS hands over an APNs token, and it can
/// fire before anything is listening — so the last token is replayed to each new
/// subscriber rather than lost.
public final class PushTokenBroker: @unchecked Sendable {
    public static let shared = PushTokenBroker()

    private let lock = NSLock()
    private var latest: String?
    private var continuations: [UUID: AsyncStream<String>.Continuation] = [:]

    /// Registration failed — logged, not surfaced. Remote notifications are an
    /// enhancement; nothing in the app depends on them.
    public func failed(_ error: any Error) {
        ConvexConnection.log.error(
            "APNs registration failed: \(String(describing: error), privacy: .public)"
        )
    }

    public func received(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        lock.withLock {
            latest = token
            for continuation in continuations.values { continuation.yield(token) }
        }
    }

    func stream() -> AsyncStream<String> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock {
                continuations[id] = continuation
                if let latest { continuation.yield(latest) }
            }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { _ = self?.continuations.removeValue(forKey: id) }
            }
        }
    }
}
