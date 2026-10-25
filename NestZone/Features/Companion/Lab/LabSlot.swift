import ComposableArchitecture
import Foundation

/// Where the card keeps what the Lab tells it, and the only thing of the Lab
/// that a Release build carries: an empty slot with nothing behind it.
///
/// On a Debug build it holds the Lab's settings (`CompanionLab`, kept in its
/// own file on this phone); everywhere else every question has the answer
/// "nothing is pretended", so the reducer reads it without a conditional.
public struct LabSlot: Equatable {
    #if DEBUG
    @Shared var lab: CompanionLab

    init(homeID: HomeID) {
        _lab = Shared(wrappedValue: CompanionLab(), .companionLab(homeID))
    }

    /// What the card is told to pretend it looks like.
    var look: LabLook { lab.look }
    /// The card runs against the pretend house, not the real one.
    var isPretend: Bool { lab.pretend }
    /// How many people live here, when the pretend house says.
    var members: Int? { lab.pretend ? lab.members : nil }

    func wake() {
        guard lab.look.mood?.isQuiet == true else { return }
        $lab.withLock { $0.look.mood = nil }
    }

    func buyAnswered() {
        guard lab.nextBuy != nil else { return }
        $lab.withLock { $0.nextBuy = nil }
    }
    #else
    init(homeID: HomeID) {}

    var look: LabLook { LabLook() }
    var isPretend: Bool { false }
    var members: Int? { nil }

    func wake() {}
    func buyAnswered() {}
    #endif
}
