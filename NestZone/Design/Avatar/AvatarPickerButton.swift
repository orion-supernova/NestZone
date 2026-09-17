import PhotosUI
import SwiftUI

/// Your own face, and the control for changing it.
///
/// The whole flow in one place — tap, choose a source, capture or pick, crop,
/// and the wait while it uploads — so that a second screen wanting to offer a
/// profile photo adds one view and an action, not a sheet, a camera, a picker,
/// an encoder and six pieces of state it has to keep in step.
///
/// The tap is the whole avatar, not the badge on it. The badge says what the
/// circle does; it is not the part you are meant to hit. That is also why the
/// face inside is drawn `viewable: false` — a viewable `Avatar` takes the touch
/// for itself and opens full screen, which left this button reachable only at
/// its corner. Looking at the photo is the sheet's first row instead.
///
/// Whose job is what: this owns choosing and cropping, which is view work and
/// dies with the screen. The caller owns the write, because a write needs a
/// rollback and rollbacks belong in a reducer — `isBusy` and `photo` are how it
/// reports back, and there is no state here that outlives a failed upload.
public struct AvatarPickerButton: View {
    /// Keeps the crop sheet addressable. `UIImage` is not `Identifiable`, and
    /// the same photo picked twice has to count as two presentations.
    private struct Editing: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    private let initials: String
    private let seed: String
    private let name: String
    private let photo: URL?
    private let size: CGFloat
    private let isBusy: Bool
    private let onSelected: (PhotoUpload) -> Void
    private let onRemoved: () -> Void

    @Environment(\.displayScale) private var displayScale

    @State private var isChoosingSource = false
    /// What the source sheet was asked for, waiting for it to finish closing.
    @State private var chosen: AvatarSource?
    /// What the camera captured, waiting for the same.
    @State private var captured: Data?
    @State private var isPickerPresented = false
    @State private var isCameraPresented = false
    @State private var picked: PhotosPickerItem?
    @State private var isPreparing = false
    @State private var editing: Editing?
    @State private var viewing: AvatarSubject?
    @State private var isShowingUnreadable = false
    /// The crop the user just confirmed, held only until the server's own copy
    /// is loadable. Without it the avatar would drop back to initials for the
    /// length of the upload — right after the one moment the user is looking
    /// straight at it.
    @State private var pending: UIImage?

    public init(
        initials: String,
        seed: String,
        name: String,
        photo: URL?,
        size: CGFloat = 52,
        isBusy: Bool = false,
        onSelected: @escaping (PhotoUpload) -> Void,
        onRemoved: @escaping () -> Void
    ) {
        self.initials = initials
        self.seed = seed
        self.name = name
        self.photo = photo
        self.size = size
        self.isBusy = isBusy
        self.onSelected = onSelected
        self.onRemoved = onRemoved
    }

    /// True while there is a photo to look at, replace or take off — which is
    /// what decides whether the sheet offers four rows or two.
    private var hasPhoto: Bool { photo != nil || pending != nil }

    public var body: some View {
        Button { isChoosingSource = true } label: {
            AvatarPickerFace(
                initials: initials,
                seed: seed,
                photo: photo,
                pending: pending,
                size: size,
                isBusy: isBusy || isPreparing
            )
            // The face, the badge and the corner between them are one target.
            // Without this the button is only tappable where something is
            // actually drawn, which leaves a notch out of the circle.
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isBusy || isPreparing)
        .accessibilityLabel(Text(
            hasPhoto ? L10n.avatarChangePhoto : L10n.avatarAddPhoto
        ))
        // Every one of these presents the *next* thing, so each acts from
        // `onDismiss` rather than from the tap. SwiftUI will not put a sheet on
        // top of a sheet that is still going away: asked to, it logs "Currently,
        // only presenting a single sheet is supported" and presents nothing —
        // which on a phone looks exactly like a button that does not work.
        .sheet(isPresented: $isChoosingSource, onDismiss: actOnChoice) {
            AvatarSourceSheet(hasPhoto: hasPhoto) { chosen = $0 }
        }
        .photosPicker(
            isPresented: $isPickerPresented,
            selection: $picked,
            matching: .images,
            photoLibrary: .shared()
        )
        .fullScreenCover(isPresented: $isCameraPresented, onDismiss: cropCaptured) {
            CameraPicker { captured = $0 }
                .ignoresSafeArea()
        }
        .sheet(item: $editing) { subject in
            AvatarCropSheet(image: subject.image) { selection in
                pending = selection.image
                onSelected(selection.upload)
            }
        }
        .fullScreenCover(item: $viewing) { AvatarViewer(subject: $0) }
        .alert(Text(L10n.commonErrorTitle), isPresented: $isShowingUnreadable) {
            Button(role: .cancel) {} label: { Text(L10n.commonOkButton) }
        } message: {
            // Named rather than relayed: `PhotosPicker` fails with
            // transfer-machinery messages, and "The operation couldn't be
            // completed" is not something a person can act on.
            Text(L10n.avatarUnreadable)
        }
        .task(id: picked) { await loadPicked() }
        .task(id: Handover(photo: photo, isBusy: isBusy)) { await handOver() }
    }

    /// Acts on what the source sheet was asked for, once it has closed.
    private func actOnChoice() {
        guard let source = chosen else { return }
        chosen = nil
        switch source {
        case .view:
            guard let photo else { return }
            viewing = AvatarSubject(
                name: name, initials: initials, seed: seed, photo: photo
            )
        case .camera:
            isCameraPresented = true
        case .library:
            isPickerPresented = true
        case .remove:
            pending = nil
            onRemoved()
        }
    }

    /// Opens the editor on what the camera just took, once the camera has
    /// closed.
    private func cropCaptured() {
        guard let captured else { return }
        self.captured = nil
        prepare(captured)
    }

    /// Turns the picker's item into something the editor can work on.
    private func loadPicked() async {
        guard let picked else { return }
        isPreparing = true
        defer {
            isPreparing = false
            // Cleared either way, so choosing the *same* photo again still
            // counts as a change and reopens the editor.
            self.picked = nil
        }

        do {
            guard let data = try await picked.loadTransferable(type: Data.self) else {
                isShowingUnreadable = true
                return
            }
            prepare(data)
        } catch is CancellationError {
            // The view went away, or another photo was picked. Not a failure.
        } catch {
            isShowingUnreadable = true
        }
    }

    /// The one door into the editor, from the library and from the camera
    /// alike. Both hand over bytes, and neither should know what happens to
    /// them next.
    private func prepare(_ data: Data) {
        guard let image = AvatarPhoto.upright(data) else {
            isShowingUnreadable = true
            return
        }
        editing = Editing(image: image)
    }

    /// Hands the locally cropped photo over to the server's copy of it.
    ///
    /// The order is the point, and it is why this is one task and not two
    /// `onChange` handlers: the cache is primed *first*, so by the time the
    /// local preview is dropped the same bitmap is already filed under the new
    /// URL and `Avatar` draws it in the same frame. Split across two callbacks
    /// there is a frame between them, and that frame shows initials.
    private func handOver() async {
        guard let pending, !isBusy else { return }
        if let photo {
            for points in AvatarPhoto.renderBuckets {
                let edge = points * displayScale
                await ImageLoader.shared.prime(
                    AvatarPhoto.fitted(pending, toPixels: edge),
                    for: photo,
                    pixels: CGSize(width: edge, height: edge),
                    persistence: .disk
                )
            }
        }
        // Also the rollback: a refused upload ends with `isBusy` false and
        // `photo` unchanged, and dropping the preview is what puts the old
        // face back.
        self.pending = nil
    }

    /// The pair that decides when the handover happens. Both have to be
    /// watched: the URL because it is what gets primed, and `isBusy` because a
    /// write that failed never changes the URL at all.
    private struct Handover: Equatable {
        let photo: URL?
        let isBusy: Bool
    }
}
