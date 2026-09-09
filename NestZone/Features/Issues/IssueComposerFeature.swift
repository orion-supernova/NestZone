import ComposableArchitecture
import Foundation

/// Reporting a problem, or editing one.
///
/// The sheet is built around the three fields that make this module more than a
/// notes app — where, what kind, how bad — because those are what every count,
/// every grouping and every "this has happened before" is derived from. They are
/// pickers rather than text for that reason: a household that types "kitchen
/// tap" one week and "tap in kitchen" the next has written two unrelated notes,
/// and no amount of cleverness afterwards can join them up.
///
/// Everything else — a deadline, an estimate, who to call, when the warranty
/// runs out — is folded away behind a disclosure. A report has to be fast enough
/// to make while standing in front of the broken thing, or it does not get made.
@Reducer
public struct IssueComposerFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Identifiable {
        public var homeID: HomeID
        public var members: IdentifiedArrayOf<User>
        public var currentUserID: UserID?
        /// The problem being edited, if this is an edit.
        public var editing: HouseIssue?

        public var title = ""
        public var details = ""
        public var area: IssueArea = .kitchen
        public var category: IssueCategory = .other
        public var severity: IssueSeverity = .minor
        public var assignedTo: UserID?

        public var hasDeadline = false
        public var dueBy: Date = Date().addingTimeInterval(7 * 24 * 3600)

        /// The estimate, edited as text and stored as whole minor units.
        ///
        /// Not a `Decimal` binding with a currency format style: that field
        /// opens already holding "€0.00", so entering a number starts with
        /// deleting one, every time. The same habit every amount field in this
        /// app has.
        public var estimateText = ""
        public var currency: String = Money.deviceDefault

        public var vendorName = ""
        public var vendorPhone = ""
        public var vendorURL = ""
        public var hasWarranty = false
        public var warrantyUntil: Date = Date().addingTimeInterval(365 * 24 * 3600)

        /// Pictures chosen but not yet uploaded, already re-encoded for the
        /// wire. Held as bytes rather than as `PhotosPickerItem`s so the
        /// reducer owns them and the view can be rebuilt without losing them.
        ///
        /// Only on the way *in*. Editing a problem manages its photos on the
        /// detail screen, where they are already on show and can be deleted one
        /// at a time — a composer that had to reconcile "these three are
        /// already up, this one is new, that one is going" is a second photo
        /// model to keep in step.
        public var photos: [Data] = []
        public var isPreparingPhotos = false

        public var isSubmitting = false
        public var inlineError: String?
        /// Bumped to shake the sheet when it is refusing something. A refusal
        /// has to be felt, not just read.
        public var shakes = 0
        /// Whether the optional half is unfolded.
        public var showsMore = false

        public var id: String { editing?.id.rawValue ?? "new" }

        public init(
            homeID: HomeID,
            members: IdentifiedArrayOf<User>,
            currentUserID: UserID? = nil,
            area: IssueArea? = nil,
            editing: HouseIssue? = nil
        ) {
            self.homeID = homeID
            self.members = members
            self.currentUserID = currentUserID
            self.editing = editing

            if let editing {
                title = editing.title
                details = editing.details ?? ""
                self.area = editing.area
                category = editing.category
                severity = editing.severity
                assignedTo = editing.assignedTo
                if let due = editing.dueBy {
                    hasDeadline = true
                    dueBy = due.date
                }
                currency = editing.currency ?? Money.deviceDefault
                if let estimate = editing.costEstimate, estimate > 0 {
                    estimateText = Money.editableText(estimate, currency: currency)
                }
                vendorName = editing.vendorName ?? ""
                vendorPhone = editing.vendorPhone ?? ""
                vendorURL = editing.vendorURL ?? ""
                if let warranty = editing.warrantyUntil {
                    hasWarranty = true
                    warrantyUntil = warranty.date
                }
                // Reopened on the half somebody actually filled in, so nothing
                // they typed is hidden behind a disclosure they have to find.
                showsMore = editing.dueBy != nil || editing.costEstimate != nil
                    || editing.vendorName != nil || editing.vendorPhone != nil
                    || editing.warrantyUntil != nil
            } else if let area {
                self.area = area
            }
        }

        public var isEditing: Bool { editing != nil }

        /// The estimate in whole minor units — the only form the server takes.
        public var estimateMinor: Int { Money.parse(estimateText, currency: currency) }

        public var currencyOptions: [String] { Money.pickerCodes(used: [currency]) }

        /// Members in a stable order, the reporter first.
        public var orderedMembers: [User] {
            members.sorted { lhs, rhs in
                if lhs.id == currentUserID { return true }
                if rhs.id == currentUserID { return false }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
                    == .orderedAscending
            }
        }

        public var canSubmit: Bool {
            guard !isSubmitting, !isPreparingPhotos else { return false }
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        /// How many more pictures this report will take. Mirrors the server's
        /// own cap, so the picker stops offering slots the mutation would drop.
        public static let maxPhotos = 6

        public var remainingPhotoSlots: Int {
            max(0, Self.maxPhotos - photos.count)
        }

        var payload: NewIssue {
            NewIssue(
                homeID: homeID,
                title: title,
                details: details,
                area: area,
                category: category,
                severity: severity,
                assignedTo: assignedTo,
                dueBy: hasDeadline ? dueBy : nil,
                costEstimate: estimateMinor > 0 ? estimateMinor : nil,
                currency: currency,
                vendorName: vendorName,
                vendorPhone: vendorPhone,
                vendorURL: vendorURL,
                warrantyUntil: hasWarranty ? warrantyUntil : nil
            )
        }

        var edits: IssueEdit {
            IssueEdit(
                title: title,
                details: details,
                area: area,
                category: category,
                severity: severity,
                // The doubled optional says "clear it" rather than "leave it
                // alone" — a household that decides a repair has no deadline
                // after all has to be able to say so.
                dueBy: .some(hasDeadline ? dueBy : nil),
                costEstimate: .some(estimateMinor > 0 ? estimateMinor : nil),
                currency: currency,
                vendorName: vendorName,
                vendorPhone: vendorPhone,
                vendorURL: vendorURL,
                warrantyUntil: .some(hasWarranty ? warrantyUntil : nil)
            )
        }
    }

    public enum Action: BindableAction {
        case submitTapped
        /// Images straight from the picker, before re-encoding.
        case photosPicked([Data])
        case photosPrepared([Data])
        case photoRemoved(Int)
        case severityTapped(IssueSeverity)
        case areaTapped(IssueArea)
        case categoryTapped(IssueCategory)
        case assigneeTapped(UserID?)
        case moreToggled
        case saved
        case failed(AppError)
        case binding(BindingAction<State>)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case saved
        }
    }

    @Dependency(\.issues) var issuesClient
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .submitTapped:
                guard state.canSubmit else {
                    state.shakes += 1
                    state.inlineError = String(localized: L10n.issuesErrorTitle)
                    return .none
                }
                state.isSubmitting = true
                state.inlineError = nil

                if let editing = state.editing?.id {
                    let edits = state.edits
                    return .run { send in
                        try await issuesClient.update(editing, edits)
                        await send(.saved)
                    } catch: { error, send in
                        await send(.failed(AppError(error)))
                    }
                }

                let payload = state.payload
                let photos = state.photos
                return .run { send in
                    // The pictures go up first and the report carries their ids,
                    // so a report is never written half-illustrated: if an
                    // upload fails the whole thing fails and the sheet is still
                    // there, with everything typed into it, to try again.
                    var stored: [String] = []
                    for photo in photos {
                        stored.append(try await issuesClient.uploadPhoto(photo))
                    }
                    var report = payload
                    report.photos = stored
                    _ = try await issuesClient.create(report)
                    await send(.saved)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case let .photosPicked(images):
                guard !images.isEmpty else { return .none }
                state.isPreparingPhotos = true
                let room = state.remainingPhotoSlots
                return .run { send in
                    // Re-encoded off the main actor: re-drawing a
                    // twelve-megapixel photo is tens of milliseconds each, and
                    // doing it on the way to a `@State` array is a visible
                    // stutter in a sheet somebody is still typing into.
                    let prepared = images
                        .prefix(room)
                        .compactMap(IssuePhoto.encode)
                    await send(.photosPrepared(Array(prepared)))
                }

            case let .photosPrepared(images):
                state.isPreparingPhotos = false
                state.photos.append(contentsOf: images.prefix(state.remainingPhotoSlots))
                return .none

            case let .photoRemoved(index):
                guard state.photos.indices.contains(index) else { return .none }
                state.photos.remove(at: index)
                return .none

            case let .severityTapped(severity):
                state.severity = severity
                return .none

            case let .areaTapped(area):
                state.area = area
                return .none

            case let .categoryTapped(category):
                state.category = category
                return .none

            case let .assigneeTapped(userID):
                // Tapping the person already holding it puts it back on nobody,
                // so "actually, not me" is one tap rather than a hunt for a
                // clear control.
                state.assignedTo = state.assignedTo == userID ? nil : userID
                return .none

            case .moreToggled:
                state.showsMore.toggle()
                return .none

            case .saved:
                state.isSubmitting = false
                return .send(.delegate(.saved))

            case let .failed(error):
                state.isSubmitting = false
                guard !error.isSilent else { return .none }
                state.inlineError = error.errorDescription
                state.shakes += 1
                return .none

            case .binding, .delegate:
                return .none
            }
        }
    }
}
