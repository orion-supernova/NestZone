import ComposableArchitecture
import Foundation
import UIKit
import UserNotifications

/// Settings → Notifications: which pushes arrive, and when to keep quiet.
///
/// The choice is the person's (every phone, every house) and only decides what
/// is pushed; the bell's feed keeps everything. So the switches work whether
/// or not the system allows notifications, and the page says so when it does
/// not.
///
/// A switch flips at once and the write follows 400 ms after the last tap, so a
/// run of taps is one write. `base` is what the server last confirmed: a failed
/// write puts the page back to it, which is the state before the whole run.
/// One write is in flight at a time; edits made meanwhile go in the next.
@Reducer
public struct NotificationSettingsFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        /// What the page shows.
        public var prefs = NotificationPrefs()
        /// What the server last confirmed (or sent), the rollback target.
        public var base = NotificationPrefs()
        public var isLoaded = false
        public var isWriting = false
        public var status: UNAuthorizationStatus
        @Shared(.pro) public var pro: ProStatus
        @Presents public var alert: AlertState<Action.Alert>?

        public init(status: UNAuthorizationStatus) {
            self.status = status
        }

        public var systemOn: Bool {
            [.authorized, .provisional, .ephemeral].contains(status)
        }

        /// Edits not yet confirmed, for a page that closes before its write.
        public var unsent: NotificationPrefs? { prefs == base ? nil : prefs }
    }

    public enum Action {
        case task
        case refreshStatus
        case statusLoaded(UNAuthorizationStatus)
        case turnOnTapped
        case openSystemSettingsTapped
        case loaded(NotificationPrefs)
        case topicToggled(NotificationTopic, Bool)
        case groupToggled(NotificationGroup, Bool)
        case quietToggled(Bool)
        case quietTimesChanged(start: Int, end: Int)
        case flush
        case saved(NotificationPrefs)
        case saveFailed(AppError)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        public enum Alert: Equatable {}

        @CasePathable
        public enum Delegate: Equatable {
            /// The system answer changed, so Settings' row says the same.
            case statusChanged(UNAuthorizationStatus)
            case enabled
        }
    }

    private enum CancelID { case prefs, save }

    @Dependency(\.notificationPrefs) var client
    @Dependency(\.push) var push
    @Dependency(\.openURL) var openURL
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .merge(
                    .send(.refreshStatus),
                    .run { send in
                        for try await prefs in client.mine() {
                            await send(.loaded(prefs))
                        }
                    } catch: { _, _ in
                        // Until it answers the switches stay shut; there is
                        // nothing here worth an alert.
                    }
                    .cancellable(id: CancelID.prefs, cancelInFlight: true)
                )

            case .refreshStatus:
                return .run { send in
                    await send(.statusLoaded(push.authorizationStatus()))
                }

            case let .statusLoaded(status):
                guard status != state.status else { return .none }
                state.status = status
                return .send(.delegate(.statusChanged(status)))

            case .turnOnTapped:
                return .run { send in
                    let granted = await push.requestAuthorization()
                    await send(.statusLoaded(push.authorizationStatus()))
                    if granted { await send(.delegate(.enabled)) }
                }

            case .openSystemSettingsTapped:
                return .run { _ in
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    await openURL(url)
                }

            case let .loaded(prefs):
                state.isLoaded = true
                // Unsent edits or a write in flight are newer than this push.
                guard !state.isWriting, state.prefs == state.base else { return .none }
                state.prefs = prefs
                state.base = prefs
                return .none

            case let .topicToggled(topic, isOn):
                guard state.isLoaded else { return .none }
                state.prefs.set(topic, on: isOn)
                return edited()

            case let .groupToggled(group, isOn):
                guard state.isLoaded else { return .none }
                for topic in group.topics { state.prefs.set(topic, on: isOn) }
                return edited()

            case let .quietToggled(isOn):
                guard state.isLoaded else { return .none }
                state.prefs.quiet = isOn ? QuietHours() : nil
                return edited()

            case let .quietTimesChanged(start, end):
                guard state.isLoaded, state.prefs.quiet != nil else { return .none }
                // The zone is the phone's now, so travelling and editing again
                // moves the window with the person.
                state.prefs.quiet = QuietHours(start: start, end: end)
                return edited()

            case .flush:
                guard !state.isWriting, state.prefs != state.base else { return .none }
                state.isWriting = true
                let sent = state.prefs
                return .run { send in
                    do {
                        // Unstructured on purpose: leaving the page cancels
                        // this effect, and a write that was already sent
                        // should still land.
                        _ = try await Task { try await client.set(sent) }.value
                        await send(.saved(sent))
                    } catch {
                        await send(.saveFailed(AppError(error)))
                    }
                }

            case let .saved(sent):
                state.isWriting = false
                state.base = sent
                // Edited while that was in flight: the next write is due.
                return state.prefs == state.base ? .none : edited()

            case let .saveFailed(error):
                state.isWriting = false
                state.prefs = state.base
                state.alert = .failure(error)
                return .cancel(id: CancelID.save)

            case .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    /// The write, 400 ms after the last edit.
    private func edited() -> Effect<Action> {
        .run { send in
            try await clock.sleep(for: .milliseconds(400))
            await send(.flush)
        }
        .cancellable(id: CancelID.save, cancelInFlight: true)
    }
}
