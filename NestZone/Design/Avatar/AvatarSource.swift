import SwiftUI

/// The four things you can do to a profile photo.
public enum AvatarSource: String, Identifiable, CaseIterable, Sendable {
    /// Look at the one that is already there, full screen.
    case view
    case camera
    case library
    case remove

    public var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .view: L10n.avatarViewPhoto
        case .camera: L10n.avatarTakePhoto
        case .library: L10n.avatarChoosePhoto
        case .remove: L10n.avatarRemovePhoto
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .view: L10n.avatarViewPhotoDetail
        case .camera: L10n.avatarTakePhotoDetail
        case .library: L10n.avatarChoosePhotoDetail
        case .remove: L10n.avatarRemovePhotoDetail
        }
    }

    var symbol: String {
        switch self {
        case .view: "person.crop.circle"
        case .camera: "camera.fill"
        case .library: "photo.on.rectangle.angled"
        case .remove: "trash.fill"
        }
    }

    /// Only one of these takes something away, and it is the one that has to
    /// look unlike the others before it is read.
    var isDestructive: Bool { self == .remove }
}
