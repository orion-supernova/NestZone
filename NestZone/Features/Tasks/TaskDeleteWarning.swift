import ComposableArchitecture
import Foundation

/// The one dialog in the app whose job is to talk somebody out of something.
///
/// Deleting a finished chore takes the household's record of who did it with
/// the chore — that is not a side effect to be regretted afterwards, it is the
/// thing being asked for, and the only honest way to offer it is to say so
/// first. So this says what it costs rather than asking whether you are sure:
/// it names the chore, names whose credit goes with it, and says the
/// contribution split will change.
///
/// Shared by the Tasks screen and the Archive, which offer the same delete on
/// either side of the thirty-day boundary. Generic over the confirming action
/// so each can route it into its own alert enum — one sentence, written once. A
/// warning that varied by which list you happened to be standing on would be
/// two different promises about one act.
enum TaskDeleteWarning {
    static func alert<Action>(
        chore title: String,
        creditedTo name: String?,
        isMine: Bool,
        confirm: Action
    ) -> AlertState<Action> {
        // Built before the alert rather than inside its `message` closure: the
        // sentence depends on who the chore counts for, and three branches read
        // better as a value than as control flow inside a builder.
        let consequence: String = if isMine {
            String(localized: L10n.taskArchiveDeleteMessageMine)
        } else if let name {
            String(localized: L10n.taskArchiveDeleteMessageOther(name))
        } else {
            String(localized: L10n.taskArchiveDeleteMessageUnattributed)
        }

        return AlertState {
            TextState(String(localized: L10n.taskArchiveDeleteTitle(title)))
        } actions: {
            ButtonState(role: .destructive, action: confirm) {
                TextState(String(localized: L10n.commonDelete))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonCancel))
            }
        } message: {
            TextState(consequence)
        }
    }
}
