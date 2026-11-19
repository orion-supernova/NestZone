#if DEBUG
import ComposableArchitecture
import Foundation

/// Where the card keeps what the Lab tells it: the Lab's settings
/// (`CompanionLab`, kept in its own file on this phone). Debug builds only; a
/// Release build has no Lab, and `CompanionFeature.State` answers "nothing is
/// pretended" on its own.
public struct LabSlot: Equatable {
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
}
#endif
