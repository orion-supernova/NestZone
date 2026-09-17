import SwiftUI

/// Choosing which part of a photo is the face.
///
/// A picker hands over whatever the camera took — a wide shot, a group, a photo
/// that is taller than it is wide — and the app draws it in a 26-point circle.
/// Uploading that unedited means centre-cropping somebody's shoulder, so this
/// sheet exists to let them say. The preview is the mask the app actually uses,
/// at the size it will be seen, which is the only preview worth showing: a
/// square with a note promising it will be round later is not a preview of
/// anything.
///
/// The geometry lives in `AvatarCrop`, not here. This view owns gestures and
/// the mask; where those land in the original photo is arithmetic that can be
/// checked without a screen.
struct AvatarCropSheet: View {
    let image: UIImage
    let onConfirm: (CompressedPhoto) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Committed pan and zoom. Gestures in progress are held separately.
    @State private var crop: AvatarCrop
    /// The square the photo is fitted into, measured rather than assumed — it
    /// is whatever the sheet's width leaves after padding.
    @State private var viewport: CGFloat = 0
    @State private var isEncoding = false
    @State private var failedToEncode = false

    /// Live gesture values. `@GestureState` unwinds them on its own if a
    /// gesture is cancelled, which a plain `@State` would leave stuck.
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var pan: CGSize = .zero

    init(image: UIImage, onConfirm: @escaping (CompressedPhoto) -> Void) {
        self.image = image
        self.onConfirm = onConfirm
        _crop = State(initialValue: AvatarCrop(imageSize: image.size, viewport: 0))
    }

    /// What the photo looks like this instant: committed, plus whatever is
    /// under the finger.
    private var live: AvatarCrop {
        AvatarCrop(
            imageSize: crop.imageSize,
            viewport: viewport,
            scale: crop.scale * pinch,
            offset: CGSize(
                width: crop.offset.width + pan.width,
                height: crop.offset.height + pan.height
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Metrics.sectionSpacing) {
                Spacer(minLength: 0)
                editor
                Text(L10n.avatarCropHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
            .padding(Metrics.screenPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Backdrop(tint: theme.accent))
            .navigationTitle(Text(L10n.avatarCropTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() } label: {
                        Text(L10n.commonCancel)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: confirm) {
                        if isEncoding {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(L10n.avatarCropConfirm)
                        }
                    }
                    .disabled(isEncoding || viewport <= 0)
                }
            }
            .alert(
                Text(L10n.commonErrorTitle),
                isPresented: $failedToEncode
            ) {
                Button(role: .cancel) { failedToEncode = false } label: {
                    Text(L10n.commonOkButton)
                }
            } message: {
                Text(L10n.avatarCropFailedMessage)
            }
            // Dragging downwards is how the photo is positioned, and it is also
            // how a sheet is thrown away. Without this the two fight, and the
            // one that wins is the one that loses the user's work. Cancel is
            // still right there.
            .interactiveDismissDisabled()
        }
    }

    private var editor: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    // Fitted to the shorter edge so the circle is full at every
                    // zoom. This *is* `AvatarCrop.fillScale`, drawn.
                    .aspectRatio(contentMode: .fill)
                    .frame(width: viewport, height: viewport)
                    .scaleEffect(live.scale)
                    .offset(live.offset)
            }
            .clipped()
            .overlay { CropCircleMask() }
            .contentShape(.rect)
            .gesture(gesture)
            // The modern reading of a laid-out size. A `GeometryReader` here
            // would take the whole width and height it was given and push the
            // hint text off the bottom.
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                viewport = width
                crop.viewport = width
                crop = crop.clamped()
            }
            .accessibilityElement()
            .accessibilityLabel(Text(L10n.avatarCropAccessibilityLabel))
            .accessibilityValue(Text(L10n.avatarCropAccessibilityValue(Int(live.scale * 100))))
            .accessibilityAdjustableAction(adjust)
    }

    private var gesture: some Gesture {
        SimultaneousGesture(
            MagnifyGesture()
                .updating($pinch) { value, state, _ in state = value.magnification }
                .onEnded { value in
                    settle { crop.scale *= value.magnification }
                },
            DragGesture()
                .updating($pan) { value, state, _ in state = value.translation }
                .onEnded { value in
                    settle {
                        crop.offset.width += value.translation.width
                        crop.offset.height += value.translation.height
                    }
                }
        )
    }

    /// Commits a gesture and lets the result spring back inside its limits.
    ///
    /// Clamped here rather than while the finger is down: correcting live makes
    /// a pinch past the limit feel like the photo is fighting back, where
    /// settling afterwards reads as the photo finding its place.
    private func settle(_ change: () -> Void) {
        change()
        withAnimation(reduceMotion ? Motion.fade : Motion.spring) {
            crop = crop.clamped()
        }
    }

    /// VoiceOver's swipe-up/down on the editor, which is the only way to zoom
    /// without a pinch.
    private func adjust(_ direction: AccessibilityAdjustmentDirection) {
        settle {
            switch direction {
            case .increment: crop.scale += 0.25
            case .decrement: crop.scale -= 0.25
            @unknown default: break
            }
        }
    }

    private func confirm() {
        guard !isEncoding else { return }
        isEncoding = true
        guard let selection = AvatarPhoto.encode(image, crop: crop.clamped()) else {
            // A photo with no bitmap behind it, or a crop that came out empty.
            // Said out loud: silently dismissing would look exactly like a
            // change that worked.
            isEncoding = false
            failedToEncode = true
            return
        }
        onConfirm(selection)
        dismiss()
    }
}
