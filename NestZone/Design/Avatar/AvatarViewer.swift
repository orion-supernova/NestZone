import SwiftUI

/// Somebody's face, as large as the screen will allow.
///
/// Built like every other photo viewer on the phone, because that is the whole
/// requirement: pinch or double-tap to zoom, drag to move it once zoomed, and
/// flick it downwards to put it away. Anything invented here would be a thing
/// to learn.
///
/// The gesture rule that makes it feel right: a downward drag means *close*
/// while the photo is at rest, and *pan* the moment it is zoomed in. Without
/// that split, zooming in traps you — every attempt to look at the bottom of
/// the picture throws it off the screen instead.
struct AvatarViewer: View {
    let subject: AvatarSubject

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A unit square, because every avatar is one: `AvatarPhoto.square` is the
    /// only thing that ever produces the file, and it squares the crop off
    /// before uploading. Only the ratio is used, so the units do not matter —
    /// and a photo that somehow was not square would letterback here and be
    /// given slightly generous pan limits, which is harmless.
    @State private var zoom = PhotoZoom(
        imageSize: CGSize(width: 1, height: 1),
        viewport: .zero
    )
    @State private var viewport: CGSize = .zero
    /// How far it has been flicked towards the bottom of the screen. Drives the
    /// backdrop's fade, so the photo looks like it is being lifted off it.
    @State private var dismissOffset: CGFloat = 0

    @GestureState private var pinch: CGFloat = 1
    @GestureState private var pan: CGSize = .zero

    /// Past this, letting go closes it.
    private static let dismissThreshold: CGFloat = 140

    private var live: PhotoZoom {
        PhotoZoom(
            imageSize: zoom.imageSize,
            viewport: viewport,
            scale: zoom.scale * pinch,
            offset: CGSize(
                width: zoom.offset.width + pan.width,
                height: zoom.offset.height + pan.height
            )
        )
    }

    /// 1 at rest, fading towards 0 as the photo is flicked away.
    private var backdropOpacity: Double {
        max(0, 1 - Double(abs(dismissOffset) / (Self.dismissThreshold * 2)))
    }

    var body: some View {
        ZStack {
            Palette.viewerBackdrop
                .opacity(backdropOpacity)
                .ignoresSafeArea()

            photo
        }
        .overlay(alignment: .top) { AvatarViewerBar(name: subject.name, close: close) }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            viewport = size
            zoom.viewport = size
            zoom = zoom.clamped()
        }
        // The photo is the whole screen and it is already described; a swipe
        // through its parts would find a picture and two buttons.
        .accessibilityAddTraits(.isModal)
        .statusBarHidden()
    }

    private var photo: some View {
        RemoteImage(
            url: subject.photo,
            targetSize: CGSize(
                width: AvatarPhoto.viewerEdge,
                height: AvatarPhoto.viewerEdge
            ),
            contentMode: .fit,
            persistence: .disk
        ) {
            // Their initials on their own colour, not a spinner. The viewer
            // asks for a bigger pixel size than any list does, so the first
            // open of a face is a real load — and this at least holds the
            // space with something that is recognisably the right person.
            AvatarInitials(initials: subject.initials, seed: subject.seed, size: 120)
        }
        .scaleEffect(live.scale)
        .offset(
            x: live.offset.width,
            y: live.offset.height + dismissOffset
        )
        .gesture(magnify)
        .simultaneousGesture(drag)
        .onTapGesture(count: 2) { settle { zoom = zoom.toggledZoom() } }
        .accessibilityLabel(Text(L10n.avatarViewerAccessibility(subject.name)))
        .accessibilityValue(Text(L10n.avatarCropAccessibilityValue(Int(live.scale * 100))))
        .accessibilityAdjustableAction(adjust)
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in settle { zoom.scale *= value.magnification } }
    }

    private var drag: some Gesture {
        DragGesture()
            .updating($pan) { value, state, _ in
                // Only while zoomed. At rest the same finger movement is
                // driving `dismissOffset` below, and letting both have it would
                // move the photo twice as far as the finger.
                state = zoom.isAtRest ? .zero : value.translation
            }
            .onChanged { value in
                guard zoom.isAtRest else { return }
                dismissOffset = value.translation.height
            }
            .onEnded { value in
                guard zoom.isAtRest else {
                    settle {
                        zoom.offset.width += value.translation.width
                        zoom.offset.height += value.translation.height
                    }
                    return
                }
                // Predicted, not actual: a quick flick that has not travelled
                // far is still unmistakably a throw, and waiting for the
                // distance makes the gesture feel like it needs convincing.
                if abs(value.predictedEndTranslation.height) > Self.dismissThreshold {
                    dismiss()
                } else {
                    withAnimation(reduceMotion ? Motion.fade : Motion.spring) {
                        dismissOffset = 0
                    }
                }
            }
    }

    private func settle(_ change: () -> Void) {
        change()
        withAnimation(reduceMotion ? Motion.fade : Motion.spring) {
            zoom = zoom.clamped()
        }
    }

    private func close() {
        dismiss()
    }

    /// VoiceOver's swipe-up/down, which is the only way to zoom without a pinch.
    private func adjust(_ direction: AccessibilityAdjustmentDirection) {
        settle {
            switch direction {
            case .increment: zoom.scale += 0.5
            case .decrement: zoom.scale -= 0.5
            @unknown default: break
            }
        }
    }
}
