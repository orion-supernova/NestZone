import SwiftUI

/// A person: their photo if they have one, their initials if they do not.
///
/// The signature has not changed — `initials`, `seed`, `size` — and that is the
/// point. Every call site in the app already hands over the user's id as the
/// colour seed, because the tint has to match their slice of the contributions
/// ring, and an id is all `AvatarDirectory` needs to find a face. So a screen
/// that was drawing initials yesterday draws photographs today without being
/// edited, and the next feature to show a member gets it for nothing.
///
/// The initials are not a loading state to be got past; they are the other half
/// of the component. Most households will have members who never set a photo,
/// and a missing one has to look deliberate rather than broken — so the tile is
/// the placeholder, which means it is also what holds the space while a photo
/// arrives, what shows if the file has been deleted, and what a household sees
/// with no signal. There is no layout in which this view has nothing to draw.
///
/// Tapping one opens it full screen, wherever it is drawn — which is the same
/// trick again: the name for the title comes out of the directory, so no caller
/// has to pass one. It is off wherever the avatar sits inside a control that owns
/// the tap — including `AvatarPickerButton`, whose whole circle is the control
/// (see `viewable`).
public struct Avatar: View {
    /// Where the photo comes from.
    public enum Source: Equatable, Sendable {
        /// Look the seed up. Right for anywhere the caller has a member row
        /// rather than a whole `User` — which is thirteen of the fourteen
        /// places this view is used.
        case directory
        /// The caller already knows, and can say so. Saves nothing in
        /// performance; it exists so a screen holding a `User` does not depend
        /// on a subscription elsewhere having filled the directory first.
        case photo(URL?)
    }

    private let initials: String
    private let seed: String
    private let size: CGFloat
    private let source: Source
    private let viewable: Bool

    /// The photo being shown full screen, if any. An optional item rather
    /// than a flag and a value: there is no state in which one is presented
    /// without the other.
    @State private var viewing: AvatarSubject?

    /// - Parameter viewable: whether tapping opens the photo full screen.
    ///   Defaults to on, so a new screen gets it without asking. Turned **off**
    ///   wherever the avatar is inside something whose tap means something else
    ///   — a member-selection row, a settle-up suggestion, a `Menu` label —
    ///   because there the tap belongs to the control, not to the face in it.
    public init(
        initials: String,
        seed: String,
        size: CGFloat = 36,
        source: Source = .directory,
        viewable: Bool = true
    ) {
        self.initials = initials
        self.seed = seed
        self.size = size
        self.source = source
        self.viewable = viewable
    }

    /// For the one screen that holds the whole person.
    public init(user: User, size: CGFloat = 36, viewable: Bool = true) {
        self.init(
            initials: user.initials,
            seed: user.id.rawValue,
            size: size,
            source: .photo(user.avatarURL),
            viewable: viewable
        )
    }

    private var photo: URL? {
        switch source {
        case .directory: AvatarDirectory.shared.url(for: seed)
        case let .photo(url): url
        }
    }

    /// There is nothing to open full screen but a photograph. Initials at
    /// twenty times their size are not a picture of anybody.
    private var canView: Bool { viewable && photo != nil }

    /// What to call them. The directory holds it because `homes:members`
    /// delivers it, so no caller has to start passing a name in order for a
    /// photo to have a title.
    private var name: String {
        AvatarDirectory.shared.name(for: seed) ?? String(localized: L10n.avatarSomeone)
    }

    private var subject: AvatarSubject? {
        guard let photo else { return nil }
        return AvatarSubject(name: name, initials: initials, seed: seed, photo: photo)
    }

    public var body: some View {
        // Rounded onto one of two sizes rather than the size it is drawn at, so
        // the same member in a comment, a chip and a list is one decoded bitmap
        // instead of three. See `AvatarPhoto.renderSize`.
        let render = AvatarPhoto.renderSize(for: size)
        return RemoteImage(
            url: photo,
            targetSize: CGSize(width: render, height: render),
            contentMode: .fill,
            // A face belongs on disk. It is drawn on nearly every screen in the
            // app, and it should be there on the first frame of a cold launch
            // with no network.
            persistence: .disk
        ) {
            AvatarInitials(initials: initials, seed: seed, size: size)
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .contentShape(.circle)
        .onTapGesture { viewing = subject }
        // The load-bearing line. `false` makes the whole avatar transparent to
        // touches, so a tap lands on whatever is behind it — which in half the
        // app is the row, chip or menu the avatar is sitting inside. A
        // `.onTapGesture` that is merely *inert* would still swallow the tap and
        // break selection everywhere.
        //
        // A tap gesture rather than a `Button` for the same reason: this is
        // routinely nested inside another button, and nested buttons in a list
        // row are a coin toss about which one gets the touch. The `.isButton`
        // trait below is what keeps VoiceOver correct without one.
        .allowsHitTesting(canView)
        // Decorative when it cannot be opened: every call site draws this beside
        // the name it belongs to, so announcing it would read the same person
        // twice. Once it *is* a control, it has to be reachable and named.
        .accessibilityHidden(!canView)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(L10n.avatarViewerAccessibility(name)))
        .fullScreenCover(item: $viewing) { AvatarViewer(subject: $0) }
    }
}
