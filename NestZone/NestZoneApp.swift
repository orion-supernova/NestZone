//
//  NestZoneApp.swift
//  NestZone
//

import ComposableArchitecture
import SwiftUI

/// The app target is a shell. Everything real lives in `Packages/NestZoneKit`,
/// which builds and previews without the app around it.
@main
struct NestZoneApp: App {
    /// One store for the process. `Store` is reference-typed, so this is a
    /// stable root rather than something SwiftUI may recreate.
    @MainActor
    private static let store = Store(initialState: AppFeature.State()) {
        #if DEBUG
        AppFeature()._printChanges(.actionLabels)
        #else
        AppFeature()
        #endif
    }

    /// The APNs device token arrives through a `UIApplicationDelegate` callback
    /// and nowhere else, so the app keeps a delegate purely to forward it.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // The Settings door to the glass bench is behind sign-in and a
            // home, which is no use on a fresh simulator. This one is not:
            //   xcrun simctl launch booted com.walhallaa.NestZone -glassLab
            if ProcessInfo.processInfo.arguments.contains("-glassLab") {
                GlassListLab()
            } else {
                root
            }
            #else
            root
            #endif
        }
    }

    private var root: some View {
        AppView(store: Self.store)
            // The window exists by the time its content appears, which is the
            // earliest the recogniser has anything to attach to.
            .onAppear { KeyboardDismisser.shared.install() }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Needed for a notification to show while the app is foregrounded —
        // without a delegate iOS suppresses it, which is wrong for a timer.
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushTokenBroker.shared.received(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        // Expected on a simulator without a paired push environment; the app is
        // fully usable without remote notifications.
        PushTokenBroker.shared.failed(error)
    }

    /// Show household activity even while the app is open — the point is that
    /// someone else changed something you are looking at.
    ///
    /// `nonisolated` with the completion-handler form: neither `UNNotification`
    /// nor `UNUserNotificationCenter` is `Sendable`, so the async variant cannot
    /// hop them onto the main actor.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
