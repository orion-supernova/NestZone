#if DEBUG
import ComposableArchitecture
import Foundation
import os

/// Runs `CompanionFeature` against the real house, or against the pretend one.
///
/// This is where the pretend house is kept apart from the real one. When the
/// Lab's master switch is on, every action of the feature is reduced inside a
/// dependency scope that replaces `CompanionClient` with the stand-in server's
/// and the Sparkles store with its own (`FakeNestieServer`), so each effect
/// the feature starts — the live read, a care tap, a purchase, a vote — is
/// created holding the stand-in and cannot hold the live one. Nothing in the
/// feature knows which it has.
///
/// Two more things keep it honest. The live client refuses, and logs, any call
/// made while the switch is on (`PretendRoute`), so an effect that was already
/// running when the switch was turned cannot write to the real house either.
/// And turning the switch resets the card (`resetForSource`), so nothing the
/// real house said is ever shown as the pretend one's, or the other way round.
///
/// Release builds do not compile this: `MainFeature` scopes `CompanionFeature`
/// itself.
struct CompanionHost: Reducer {
    typealias State = CompanionFeature.State
    typealias Action = CompanionFeature.Action

    @Dependency(\.pretendHouse) var pretendHouse

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        let pretending = state.isPretend
        PretendRoute.isOn = pretending
        guard pretending else { return CompanionFeature().reduce(into: &state, action: action) }
        let server = pretendHouse
        return withDependencies {
            $0.companion = server.client
            $0.sparkleStore = server.store
        } operation: {
            CompanionFeature().reduce(into: &state, action: action)
        }
    }
}

/// Whether the card is running against the pretend house right now, as the
/// live client can see it. Set by `CompanionHost` on every action, before the
/// feature runs.
enum PretendRoute {
    private static let flag = LockIsolated(false)
    private static let log = Logger(subsystem: "com.walhallaa.NestZone", category: "Companion")

    static var isOn: Bool {
        get { flag.value }
        set { flag.setValue(newValue) }
    }

    /// Said by the live client when it is called in pretend mode, and then
    /// refused: a call that should not have happened is a bug to find.
    static func refuse(_ name: String) -> AppError {
        log.fault("blocked live companion call \(name, privacy: .public) while the pretend house is on")
        return .cancelled
    }
}

extension CompanionClient {
    /// This client, refusing every call while the pretend house is on.
    func refusingWhilePretending() -> CompanionClient {
        CompanionClient(
            forHome: { id in
                guard !PretendRoute.isOn else { return Self.refused("forHome") }
                return self.forHome(id)
            },
            album: { id in
                guard !PretendRoute.isOn else { return Self.refused("album") }
                return self.album(id)
            },
            setPlace: { id, place in
                guard !PretendRoute.isOn else { throw PretendRoute.refuse("setPlace") }
                return try await self.setPlace(id, place)
            },
            start: { id, species, place, request, colour in
                guard !PretendRoute.isOn else { throw PretendRoute.refuse("start") }
                return try await self.start(id, species, place, request, colour)
            },
            care: { id in
                guard !PretendRoute.isOn else { throw PretendRoute.refuse("care") }
                return try await self.care(id)
            },
            graduate: { id, companion in
                guard !PretendRoute.isOn else { throw PretendRoute.refuse("graduate") }
                return try await self.graduate(id, companion)
            },
            ballot: { poll, species, answer in
                guard !PretendRoute.isOn else { throw PretendRoute.refuse("ballot") }
                try await self.ballot(poll, species, answer)
            },
            decide: { id in
                guard !PretendRoute.isOn else { throw PretendRoute.refuse("decide") }
                return try await self.decide(id)
            },
            setLayout: { id, layout in
                guard !PretendRoute.isOn else { throw PretendRoute.refuse("setLayout") }
                return try await self.setLayout(id, layout)
            },
            setHolidays: { id, holidays in
                guard !PretendRoute.isOn else { throw PretendRoute.refuse("setHolidays") }
                return try await self.setHolidays(id, holidays)
            },
            importLocal: { id, local, place in
                guard !PretendRoute.isOn else { throw PretendRoute.refuse("importLocal") }
                return try await self.importLocal(id, local, place)
            },
            buy: { id, item, request, expected in
                guard !PretendRoute.isOn else { throw PretendRoute.refuse("buy") }
                return try await self.buy(id, item, request, expected)
            },
            topUp: { id, transaction in
                guard !PretendRoute.isOn else { throw PretendRoute.refuse("topUp") }
                return try await self.topUp(id, transaction)
            }
        )
    }

    private static func refused<Element: Sendable>(_ name: String) -> AsyncThrowingStream<Element, any Error> {
        AsyncThrowingStream { $0.finish(throwing: PretendRoute.refuse(name)) }
    }
}

// MARK: - The dependency

private enum PretendHouseKey: DependencyKey {
    /// This phone's pretend house: one file, kept between launches.
    static var liveValue: FakeNestieServer { .device }
    /// A test gets a house of its own, in memory.
    static var testValue: FakeNestieServer { FakeNestieServer() }
}

extension DependencyValues {
    /// The pretend house `CompanionHost` swaps in, and the Lab drives.
    var pretendHouse: FakeNestieServer {
        get { self[PretendHouseKey.self] }
        set { self[PretendHouseKey.self] = newValue }
    }
}
#endif
