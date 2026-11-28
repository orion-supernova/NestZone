import ComposableArchitecture
import Foundation

@Reducer
public struct CreateHomeFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var name = ""
        public var isSubmitting = false
        public var didSucceed = false
        /// Cleared on every submit and set again on a rejection, so two
        /// identical errors in a row are still two refusals to the field.
        public var inlineError: String?

        public init() {}

        public var canSubmit: Bool {
            !isSubmitting && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public enum Action: Equatable, BindableAction {
        case submitTapped
        case succeeded
        case failed(AppError)
        /// Bubbles up so the parent can dismiss.
        case finished
        case binding(BindingAction<State>)
    }

    @Dependency(\.homes) var homes
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .submitTapped:
                // Re-entrancy guard: two taps in one frame both queue work
                // before `isSubmitting` renders, so a disabled button is not
                // enough on its own.
                guard state.canSubmit else { return .none }
                state.isSubmitting = true
                state.inlineError = nil
                return .run { [name = state.name] send in
                    try await homes.create(name)
                    await send(.succeeded)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case .succeeded:
                state.isSubmitting = false
                state.didSucceed = true
                // Hold the success state briefly so the checkmark is seen,
                // then let the parent dismiss.
                return .run { send in
                    try await clock.sleep(for: .milliseconds(700))
                    await send(.finished)
                }

            case let .failed(error):
                state.isSubmitting = false
                state.inlineError = error.errorDescription
                return .none

            case .finished, .binding:
                return .none
            }
        }
    }
}

@Reducer
public struct JoinHomeFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var code = ""
        public var isSubmitting = false
        public var didSucceed = false
        public var inlineError: String?
        /// The camera is up, looking for an invite's QR code.
        public var isScanning = false

        public init() {}

        public var canSubmit: Bool {
            !isSubmitting && !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public enum Action: Equatable, BindableAction {
        case submitTapped
        case succeeded
        case failed(AppError)
        case finished
        case scanTapped
        /// The camera read a QR code (any text; only our links are used).
        case scanned(String)
        case binding(BindingAction<State>)
    }

    @Dependency(\.homes) var homes
    @Dependency(\.invite) var invite
    @Dependency(\.paywall) var paywall
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .submitTapped:
                guard state.canSubmit else { return .none }
                state.isSubmitting = true
                state.inlineError = nil
                // A link or token goes through the invite; anything else is
                // the old invite code, which keeps working.
                return .run { [code = state.code] send in
                    if let token = InviteLink.token(in: code) {
                        do {
                            _ = try await invite.redeem(token)
                        } catch {
                            // This path never opens the paywall by itself.
                            if case .proRequired = AppError(error) { paywall.request(.multipleHomes) }
                            throw error
                        }
                    } else {
                        try await homes.join(code)
                    }
                    await send(.succeeded)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case .scanTapped:
                state.inlineError = nil
                state.isScanning = true
                return .none

            case let .scanned(text):
                state.isScanning = false
                guard InviteLink.token(in: text) != nil else {
                    state.inlineError = String(localized: L10n.joinScanWrong)
                    return .none
                }
                state.code = text
                return .send(.submitTapped)

            case .succeeded:
                state.isSubmitting = false
                state.didSucceed = true
                return .run { send in
                    try await clock.sleep(for: .milliseconds(700))
                    await send(.finished)
                }

            case let .failed(error):
                state.isSubmitting = false
                // The server answers a bad code with a bare string; turn it into
                // the localized message instead of showing raw server text.
                state.inlineError = if case let .server(message) = error,
                                       message.contains("Invalid invite code") {
                    String(localized: L10n.homeManagementInvalidInviteCode)
                } else if case let .server(message) = error,
                          message.contains("already a member") {
                    String(localized: L10n.homeManagementAlreadyMember)
                } else {
                    error.errorDescription
                }
                return .none

            case .finished, .binding:
                return .none
            }
        }
    }
}
