#if DEBUG
import ComposableArchitecture
import Foundation

/// What the Lab can ask of the card.
public enum LabAction: Equatable, Sendable {
    /// The master switch: the card runs against the pretend house, or against
    /// the real one. Either way the card is reset, so nothing one house said
    /// is ever shown as the other's.
    case pretend(Bool)

    // Look-only, both modes: laid over how the house is drawn, never written.
    case look(LabLook)
    case resetLook

    // The pretend house.
    case members(Int)
    case command(PretendCommand)
    case preset(PretendPreset)
    case moment(LabMoment)
    case nextBuy(String?)
    case latency(Int)
    case offline(Bool)
    case resetPretend
    /// Every override and every switch back to where it starts; the pretend
    /// house itself is left as it is.
    case resetOverrides
}

/// A moment to play on demand. Each one sets the pretend house up and then
/// does what a person would do, so it goes through the real machinery:
/// `State.moment`, `momentReady`, `pendingSheet`.
public enum LabMoment: Equatable, Sendable {
    /// A house nobody has welcomed picks its first: the gift.
    case welcome
    /// The next stage, paid into the jar.
    case stageUp
    /// A ready one, and its button: the ceremony.
    case ceremony
    /// A ready one, and another chosen over it: graduated in the same write,
    /// its ceremony held until nothing is open.
    case heldGraduation
    /// The last free species ready: the ceremony goes on to the finale.
    case finale
    /// The same finale, brought by choosing over the ready one.
    case finaleUnderStart
    /// Nothing growing; Choose; a new one arrives.
    case newOne
    /// A house of two graduates one, and the vote for the next opens.
    case voteOpens
    /// A holiday arrives: the day is put to it, and the chip offers its things.
    case holidayChip(Holiday.ID)
}

extension CompanionFeature {
    /// The reducer for the Lab. Everything that touches the pretend house goes
    /// to the stand-in server (`pretendHouse`), and only while the card is
    /// running against it: in the real house the Lab has no write at all.
    func reduceLab(_ action: LabAction, state: inout State) -> Effect<Action> {
        switch action {
        case let .pretend(on):
            guard state.isPretend != on else { return .none }
            state.withLab {
                $0.pretend = on
                // What was pretended about the one house means nothing to the other.
                $0.look = LabLook()
                $0.nextBuy = nil
            }
            let sync = on ? syncServer(state) : nil
            return restart(&state, first: sync)

        case let .look(look):
            state.withLab { $0.look = look }
            return .none

        case .resetLook:
            state.withLab { $0.look = LabLook() }
            return .none

        case let .members(count):
            guard state.isPretend else { return .none }
            let count = min(max(count, 1), 3)
            state.withLab { $0.members = count }
            return .run { _ in await pretendHouse.apply(.setMembers(count)) }

        case let .command(command):
            guard state.isPretend else { return .none }
            if case .chore = command { state.choreTick += 1 }
            return .run { _ in await pretendHouse.apply(command) }

        case let .preset(preset):
            guard state.isPretend else { return .none }
            let date = preset.date(now: state.now)
            state.withLab {
                $0.look = LabLook()
                $0.look.date = date
                $0.members = preset.members
                $0.nextBuy = nil
            }
            return restart(&state, first: .run { _ in await pretendHouse.apply(.preset(preset)) })

        case let .moment(moment):
            return play(moment, state: &state)

        case let .nextBuy(mode):
            guard state.isPretend else { return .none }
            state.withLab { $0.nextBuy = mode }
            return .run { _ in await pretendHouse.apply(.nextBuy(mode)) }

        case let .latency(ms):
            guard state.isPretend else { return .none }
            state.withLab { $0.latency = ms }
            return .run { _ in await pretendHouse.apply(.setLatency(ms)) }

        case let .offline(on):
            guard state.isPretend else { return .none }
            state.withLab { $0.offline = on }
            return .run { _ in await pretendHouse.apply(.setOffline(on)) }

        case .resetPretend:
            guard state.isPretend else { return .none }
            state.withLab {
                $0.look = LabLook()
                $0.members = 1
                $0.nextBuy = nil
            }
            return restart(&state, first: .run { _ in await pretendHouse.apply(.reset) })

        case .resetOverrides:
            state.withLab {
                $0.look = LabLook()
                $0.nextBuy = nil
                $0.offline = false
                $0.latency = 150
            }
            guard state.isPretend else { return .none }
            return syncServer(state)
        }
    }

    // MARK: The pretend house, set up and run again

    /// The card begins again on whichever house it is now running against:
    /// everything it held is dropped (`resetForSource`), every effect that
    /// belongs to the old one is cancelled, `first` is run (the change that
    /// makes the new house), and then the live read is opened on it.
    private func restart(_ state: inout State, first: Effect<Action>?) -> Effect<Action> {
        state.resetForSource()
        let cancels: [Effect<Action>] = [
            CancelID.served, .album, .grow, .retry, .moment, .purchases, .lab,
        ].map { .cancel(id: $0) }
        let begin: Effect<Action> = .run { send in
            await send(.task)
            await send(.watchPurchases)
        }
        guard let first else { return .merge(cancels + [begin]) }
        // The change goes first so the read opens on the house it made.
        return .merge(cancels + [.concatenate(first, begin)])
    }

    /// What the stand-in server should know that the card holds: how many
    /// people live in the house, how slow it is, whether it answers at all.
    private func syncServer(_ state: State) -> Effect<Action> {
        let lab = state.labSlot.lab
        return .run { _ in
            await pretendHouse.apply(.setMembers(lab.members))
            await pretendHouse.apply(.setLatency(lab.latency))
            await pretendHouse.apply(.setOffline(lab.offline))
            await pretendHouse.apply(.nextBuy(lab.nextBuy))
        }
    }

    // MARK: Moments

    /// A pause after the Lab's sheet has closed, so what comes next is not
    /// presented in the action that dismisses it (it would be dropped).
    private static let afterSheet: Duration = .milliseconds(700)

    private func play(_ moment: LabMoment, state: inout State) -> Effect<Action> {
        if case let .holidayChip(id) = moment { return holiday(id, state: &state) }
        guard state.isPretend else { return .none }
        // The Lab's sheet gets out of the way; the moment plays on the card.
        state.sheet = nil
        let then: Effect<Action>
        switch moment {
        case .welcome:
            then = .run { send in
                await pretendHouse.apply(.freshHouse)
                try await clock.sleep(for: Self.afterSheet)
                await send(.chose(.magnolia))
            }
        case .stageUp:
            // Nothing to close: the card is where it happens.
            return .run { _ in await pretendHouse.apply(.stageUp) }
        case .ceremony:
            then = .run { send in
                await pretendHouse.apply(.makeReady)
                try await clock.sleep(for: Self.afterSheet)
                await send(.celebrateTapped)
            }
        case .heldGraduation:
            let next = Self.another(than: state.species)
            then = .run { send in
                await pretendHouse.apply(.makeReady)
                try await clock.sleep(for: Self.afterSheet)
                await send(.chose(next))
            }
        case .finale:
            then = .run { send in
                await pretendHouse.apply(.growAllFree)
                try await clock.sleep(for: Self.afterSheet)
                await send(.celebrateTapped)
            }
        case .finaleUnderStart:
            then = .run { send in
                await pretendHouse.apply(.growAllFree)
                try await clock.sleep(for: Self.afterSheet)
                await send(.chose(.kitten))
            }
        case .newOne:
            then = .run { send in
                await pretendHouse.apply(.removeCompanion)
                try await clock.sleep(for: Self.afterSheet)
                await send(.chooseTapped)
            }
        case .voteOpens:
            state.withLab { $0.members = max($0.members, 2) }
            let members = state.labSlot.lab.members
            then = .run { send in
                await pretendHouse.apply(.setMembers(members))
                await pretendHouse.apply(.makeReady)
                try await clock.sleep(for: Self.afterSheet)
                await send(.celebrateTapped)
            }
        case .holidayChip:
            return .none
        }
        return then.cancellable(id: CancelID.lab, cancelInFlight: true)
    }

    /// A species other than the one growing, one every house can start.
    private static func another(than species: Species?) -> Species {
        [Species.kitten, .sunflower, .basil, .cactus].first { $0 != species } ?? .kitten
    }

    /// A holiday arrives: the day goes to its first day at noon, where the
    /// house is. In the pretend house the house also celebrates it and its
    /// scene is bare, so the chip has something to offer; on the real house
    /// only the day moves, and the chip shows if the house keeps that day.
    private func holiday(_ id: Holiday.ID, state: inout State) -> Effect<Action> {
        guard let holiday = Holiday.with(id),
              let start = holiday.next(after: state.now, region: state.placeRegion),
              let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: start)
        else { return .none }
        state.withLab { $0.look.date = noon }
        guard state.isPretend else { return .none }
        return .run { _ in
            await pretendHouse.apply(.celebrateAll(true))
            await pretendHouse.apply(.clearScene)
        }
    }
}

extension CompanionFeature.State {
    /// Changes the Lab's settings, which live in their own file.
    mutating func withLab(_ update: (inout CompanionLab) -> Void) {
        labSlot.$lab.withLock { update(&$0) }
    }

    /// The card begins again on a house it has not met: everything the other
    /// one said, wrote or left half-done is gone. What identifies the person
    /// and the household, and the Lab itself, stay.
    mutating func resetForSource() {
        var fresh = CompanionFeature.State(homeID: homeID, now: now, region: region)
        fresh.userID = userID
        fresh.memberCount = memberCount
        fresh.birthdays = birthdays
        fresh.completions = completions
        fresh.seen = seen
        fresh.hasLoaded = hasLoaded
        // The switch is in the Lab, and the Lab stays open.
        fresh.sheet = sheet == .lab ? .lab : nil
        self = fresh
    }
}
#endif
