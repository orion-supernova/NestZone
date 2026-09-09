import SwiftUI
import UIKit

// How a house problem looks, and the four shapes the Problems screen draws it
// with.
//
// Here rather than on the model for the same reason a spending category's
// colour is: which hue stands for "urgent" is a `Design` decision, and `Core`
// should not import SwiftUI to hold a broken tap.
//
// Nothing below allocates a colour or a gradient per frame — every tint is a
// `static let` on `Palette`, and the charts are arithmetic over `Double`s.
// Hand-rolled rather than Swift Charts, for the reasons the finance and
// contribution charts are: fixed identity colours, a glass surface the
// framework's opaque plot background fights, and a handful of marks that is
// cheaper as a dozen shapes than as a chart engine.

// MARK: - Presentation

extension IssueStatus {
    public var title: LocalizedStringResource {
        switch self {
        case .reported: L10n.issuesStatusReported
        case .acknowledged: L10n.issuesStatusAcknowledged
        case .scheduled: L10n.issuesStatusScheduled
        case .inProgress: L10n.issuesStatusInProgress
        case .blocked: L10n.issuesStatusBlocked
        case .fixed: L10n.issuesStatusFixed
        case .wontFix: L10n.issuesStatusWontFix
        }
    }

    /// What tapping it will do, said as an instruction rather than as a state.
    /// "In progress" is where you are; "Start work" is the button.
    public var advanceTitle: LocalizedStringResource {
        switch self {
        case .reported: L10n.issuesActionAcknowledge
        case .acknowledged: L10n.issuesActionSchedule
        case .scheduled: L10n.issuesActionStart
        case .blocked: L10n.issuesActionResume
        case .inProgress: L10n.issuesActionMarkFixed
        case .fixed, .wontFix: L10n.issuesActionReopen
        }
    }

    public var symbol: String {
        switch self {
        case .reported: "exclamationmark.bubble.fill"
        case .acknowledged: "eye.fill"
        case .scheduled: "calendar.badge.clock"
        case .inProgress: "wrench.and.screwdriver.fill"
        case .blocked: "hand.raised.fill"
        case .fixed: "checkmark.seal.fill"
        case .wontFix: "xmark.seal.fill"
        }
    }

    public var tint: Color {
        switch self {
        case .reported: Palette.issueReported
        case .acknowledged: Palette.issueAcknowledged
        case .scheduled: Palette.issueScheduled
        case .inProgress: Palette.issueInProgress
        case .blocked: Palette.issueBlocked
        case .fixed: Palette.issueFixed
        case .wontFix: Palette.issueWontFix
        }
    }
}

extension IssueSeverity {
    public var title: LocalizedStringResource {
        switch self {
        case .cosmetic: L10n.issuesSeverityCosmetic
        case .minor: L10n.issuesSeverityMinor
        case .major: L10n.issuesSeverityMajor
        case .urgent: L10n.issuesSeverityUrgent
        }
    }

    /// One line on what this level actually means, so a household picks the
    /// same one twice. Shown under the picker, never in a list.
    public var explainer: LocalizedStringResource {
        switch self {
        case .cosmetic: L10n.issuesSeverityCosmeticHint
        case .minor: L10n.issuesSeverityMinorHint
        case .major: L10n.issuesSeverityMajorHint
        case .urgent: L10n.issuesSeverityUrgentHint
        }
    }

    public var symbol: String {
        switch self {
        case .cosmetic: "paintbrush.fill"
        case .minor: "wrench.adjustable.fill"
        case .major: "exclamationmark.triangle.fill"
        case .urgent: "exclamationmark.octagon.fill"
        }
    }

    public var tint: Color {
        switch self {
        case .cosmetic: Palette.issueCosmetic
        case .minor: Palette.issueMinor
        case .major: Palette.issueMajor
        case .urgent: Palette.issueUrgent
        }
    }

    /// True only for the level that has already gone wrong. Decides which
    /// single row on the screen is allowed to pulse — the same rule an overdue
    /// bill follows.
    public var demandsAttention: Bool { self == .urgent }
}

extension IssueArea {
    public var title: LocalizedStringResource {
        switch self {
        case .kitchen: L10n.issuesAreaKitchen
        case .bathroom: L10n.issuesAreaBathroom
        case .bedroom: L10n.issuesAreaBedroom
        case .living: L10n.issuesAreaLiving
        case .hallway: L10n.issuesAreaHallway
        case .laundry: L10n.issuesAreaLaundry
        case .garage: L10n.issuesAreaGarage
        case .garden: L10n.issuesAreaGarden
        case .balcony: L10n.issuesAreaBalcony
        case .basement: L10n.issuesAreaBasement
        case .roof: L10n.issuesAreaRoof
        case .exterior: L10n.issuesAreaExterior
        case .whole: L10n.issuesAreaWhole
        case .other: L10n.issuesAreaOther
        }
    }

    public var symbol: String {
        switch self {
        case .kitchen: "cooktop.fill"
        case .bathroom: "shower.fill"
        case .bedroom: "bed.double.fill"
        case .living: "sofa.fill"
        case .hallway: "door.left.hand.closed"
        case .laundry: "washer.fill"
        case .garage: "car.fill"
        case .garden: "tree.fill"
        case .balcony: "sun.horizon.fill"
        case .basement: "stairs"
        case .roof: "house.and.flag.fill"
        case .exterior: "building.2.fill"
        case .whole: "house.fill"
        case .other: "questionmark.circle.fill"
        }
    }
}

extension IssueCategory {
    public var title: LocalizedStringResource {
        switch self {
        case .plumbing: L10n.issuesCategoryPlumbing
        case .electrical: L10n.issuesCategoryElectrical
        case .heating: L10n.issuesCategoryHeating
        case .appliance: L10n.issuesCategoryAppliance
        case .furniture: L10n.issuesCategoryFurniture
        case .structural: L10n.issuesCategoryStructural
        case .internet: L10n.issuesCategoryInternet
        case .pest: L10n.issuesCategoryPest
        case .damp: L10n.issuesCategoryDamp
        case .safety: L10n.issuesCategorySafety
        case .cosmetic: L10n.issuesCategoryCosmetic
        case .other: L10n.issuesCategoryOther
        }
    }

    public var symbol: String {
        switch self {
        case .plumbing: "drop.fill"
        case .electrical: "bolt.fill"
        case .heating: "thermometer.medium"
        case .appliance: "dishwasher.fill"
        case .furniture: "chair.lounge.fill"
        case .structural: "building.columns.fill"
        case .internet: "wifi"
        case .pest: "ant.fill"
        case .damp: "humidity.fill"
        case .safety: "shield.lefthalf.filled"
        case .cosmetic: "paintbrush.pointed.fill"
        case .other: "square.grid.2x2.fill"
        }
    }
}

// MARK: - How the house is holding up

/// The state of repair of one house, as a ring.
///
/// Not a count of anything: the arc is `IssueSummary.health`, which moves for
/// the reasons a household would actually say the house is in a worse state —
/// something urgent, something overdue, something broken for weeks — rather than
/// merely for *more* things. Five niggles is a to-do list; one flooded bathroom
/// is not.
///
/// The arc is a stroked path with a rounded cap and a soft shadow, the same way
/// the spend donut is drawn, so it reads as a raised band above the card rather
/// than as a flat pie. It grows from zero on appear, once.
public struct HouseHealthRing: View {
    private let health: Double
    private let openCount: Int
    private let diameter: CGFloat
    private let thickness: CGFloat

    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        health: Double,
        openCount: Int,
        diameter: CGFloat = 128,
        thickness: CGFloat = 12
    ) {
        self.health = health
        self.openCount = openCount
        self.diameter = diameter
        self.thickness = thickness
    }

    /// Green when the house is fine, amber when it is slipping, red when
    /// something is genuinely wrong. Three steps rather than a continuous hue
    /// ramp, because an arc whose colour drifts by one shade a week is an arc
    /// nobody can read a change in.
    private var tint: Color {
        if health >= 0.75 { return Palette.success }
        if health >= 0.4 { return Palette.warning }
        return Palette.danger
    }

    private var shown: Double { grown || reduceMotion ? health : 0 }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, style: .init(lineWidth: thickness, lineCap: .round))

            Circle()
                .trim(from: 0, to: max(0.001, shown))
                .stroke(tint, style: .init(lineWidth: thickness, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.45), radius: 6, y: 1)

            VStack(spacing: 1) {
                if openCount == 0 {
                    Image(systemName: "checkmark")
                        .font(.system(size: diameter * 0.3, weight: .bold))
                        .foregroundStyle(tint)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    AnimatedNumber(openCount)
                        .font(.system(size: diameter * 0.34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(L10n.issuesOpenLabel)
                        .font(.system(size: max(9, diameter * 0.1)))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(Motion.spring, value: health)
        .animation(Motion.spring, value: openCount)
        .onAppear {
            guard !grown else { return }
            withAnimation(Motion.arrive.delay(0.1)) { grown = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.issuesHealthLabel))
        .accessibilityValue(Text(health, format: .percent.precision(.fractionLength(0))))
    }
}

// MARK: - How far along

/// The rungs a problem climbs, as a track it can be dragged up one tap at a
/// time.
///
/// Only `IssueStatus.ladder` is on it. `blocked` and `wontFix` are places a
/// problem can end up rather than steps on the way somewhere, so putting them
/// on the track would say a repair has to pass through "stuck" to be finished.
/// They live in the overflow menu beside it instead.
public struct StatusTrack: View {
    private let status: IssueStatus
    private let onSelect: (IssueStatus) -> Void

    @Namespace private var pill
    @Environment(\.theme) private var theme

    public init(status: IssueStatus, onSelect: @escaping (IssueStatus) -> Void) {
        self.status = status
        self.onSelect = onSelect
    }

    /// Where a problem sitting off the track is drawn. `blocked` reads as being
    /// stuck at the rung it got stuck on, which is "being worked on" — anything
    /// else would make a stalled repair look like it had gone backwards.
    private var effective: IssueStatus {
        switch status {
        case .blocked: .inProgress
        case .wontFix: .fixed
        default: status
        }
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(IssueStatus.ladder.enumerated()), id: \.element) { index, rung in
                let isReached = effective.rank >= rung.rank
                let isHere = effective == rung

                Button { onSelect(rung) } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            if isHere {
                                Circle()
                                    .fill(status.tint)
                                    .matchedGeometryEffect(id: "issueRung", in: pill)
                                    .frame(width: 30, height: 30)
                            }
                            Image(systemName: isHere ? status.symbol : rung.symbol)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(
                                    isHere ? Color.white
                                        : (isReached ? rung.tint : Palette.accessory)
                                )
                                // Only the rung the problem is standing on
                                // reacts, and only when it arrives there.
                                .bounces(when: isHere)
                        }
                        .frame(height: 30)

                        Text(rung.title)
                            .font(.system(size: 9, weight: isHere ? .semibold : .regular))
                            .foregroundStyle(isHere ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(rung.title))
                .accessibilityAddTraits(isHere ? [.isButton, .isSelected] : .isButton)

                if index < IssueStatus.ladder.count - 1 {
                    // The connector fills as the problem passes it, so the track
                    // reads as a route travelled rather than as five buttons.
                    Capsule()
                        .fill(
                            effective.rank > rung.rank
                                ? AnyShapeStyle(status.tint.opacity(0.55))
                                : AnyShapeStyle(.quaternary)
                        )
                        .frame(height: 3)
                        .frame(maxWidth: 26)
                        .offset(y: -9)
                }
            }
        }
        .animation(Motion.spring, value: status)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - What is wrong, in one bar

/// The open problems split by how badly they matter.
///
/// A single stacked bar rather than four numbers: the question it answers is
/// "how much of what is outstanding is serious", and that is a proportion. The
/// segments are tappable, so it doubles as the severity filter — a chart nobody
/// can interrogate is a decoration.
public struct SeveritySplitBar: View {
    private let counts: [IssueSummary.SeverityCount]
    private let total: Int
    @Binding private var selection: IssueSeverity?

    @State private var grown = false

    public init(
        counts: [IssueSummary.SeverityCount],
        total: Int,
        selection: Binding<IssueSeverity?> = .constant(nil)
    ) {
        self.counts = counts
        self.total = total
        self._selection = selection
    }

    /// Ordered worst-first, so the eye lands on the serious end of the bar and
    /// the order never shuffles as counts change.
    private var ordered: [IssueSummary.SeverityCount] {
        IssueSeverity.allCases.reversed().compactMap { severity in
            counts.first { $0.severity == severity && $0.count > 0 }
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(ordered) { entry in
                        let fraction = total > 0 ? Double(entry.count) / Double(total) : 0
                        let dimmed = selection != nil && selection != entry.severity
                        Capsule()
                            .fill(entry.severity.tint)
                            .opacity(dimmed ? 0.28 : 1)
                            .frame(width: max(6, geo.size.width * (grown ? fraction : 0)))
                            .onTapGesture {
                                selection = selection == entry.severity ? nil : entry.severity
                            }
                            .accessibilityLabel(Text(entry.severity.title))
                            .accessibilityValue(Text(entry.count, format: .number))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 10)

            // The legend is the control. Reading the bar means matching a
            // colour to a word, and a chart that makes you look somewhere else
            // to do that is a chart you stop reading.
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(ordered) { entry in
                    Button {
                        selection = selection == entry.severity ? nil : entry.severity
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(entry.severity.tint)
                                .frame(width: 7, height: 7)
                            Text(entry.severity.title)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(
                                    selection == entry.severity ? .primary : .secondary
                                )
                            Text(entry.count, format: .number)
                                .font(.caption2.weight(.bold))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            entry.severity.tint.opacity(selection == entry.severity ? 0.22 : 0.1),
                            in: .capsule
                        )
                        .contentShape(.capsule)
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .animation(Motion.spring, value: counts)
        .animation(Motion.fade, value: selection)
        .onAppear { withAnimation(Motion.arrive.delay(0.15)) { grown = true } }
    }
}

// MARK: - A map of the house

/// One room, and how much is wrong with it.
///
/// The tiles are tinted by *count* rather than by a per-room hue: fourteen fixed
/// colours would be a legend nobody can hold, and the question this grid answers
/// is not "which room is this" — the symbol says that — but "where is this house
/// falling apart". A heat map answers it in one look.
public struct RoomTile: View {
    private let area: IssueArea
    private let count: Int
    /// The busiest room's count, so the grid scales to this household rather
    /// than to an absolute nobody shares.
    private let peak: Int
    private let isSelected: Bool
    private let action: () -> Void

    @Environment(\.theme) private var theme

    public init(
        area: IssueArea,
        count: Int,
        peak: Int,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.area = area
        self.count = count
        self.peak = peak
        self.isSelected = isSelected
        self.action = action
    }

    /// Nought is genuinely nothing — a clear room draws no wash at all, so the
    /// rooms that *do* have something stand out rather than merely being
    /// darker than their neighbours.
    private var heat: Double {
        guard count > 0, peak > 0 else { return 0 }
        return 0.16 + 0.34 * (Double(count) / Double(peak))
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: area.symbol)
                    .font(.title3)
                    .foregroundStyle(count > 0 ? theme.accent : Palette.accessory)
                    .bounces(when: isSelected)
                Text(area.title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(count > 0 ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if count > 0 {
                    Text(count, format: .number)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(theme.accent)
                        .contentTransition(.numericText())
                } else {
                    Text(verbatim: "—")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(Palette.accessory)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(theme.accent.opacity(heat), in: .rect(cornerRadius: Metrics.tightRadius, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: Metrics.tightRadius, style: .continuous)
                        .strokeBorder(theme.accent, lineWidth: 2)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .glassCard(cornerRadius: Metrics.tightRadius)
        .animation(Motion.spring, value: count)
        .animation(Motion.spring, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(area.title))
        .accessibilityValue(Text(count, format: .number))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Who else has hit this

/// "Happening to me too", as one tap.
///
/// The cheapest useful signal a shared house has, and the reason it is a control
/// rather than a count: one person reporting a cold radiator is a maintenance
/// note, three people reporting it is the heating.
public struct MeTooButton: View {
    private let count: Int
    private let isOn: Bool
    private let action: () -> Void

    @Environment(\.theme) private var theme

    public init(count: Int, isOn: Bool, action: @escaping () -> Void) {
        self.count = count
        self.isOn = isOn
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "hand.raised.fill" : "hand.raised")
                    .font(.caption.weight(.semibold))
                    .contentTransition(.symbolEffect(.replace))
                Text(L10n.issuesMeTooCount(count))
                    .font(.caption.weight(.semibold))
                    .contentTransition(.numericText(value: Double(count)))
            }
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if isOn { Capsule().fill(theme.accent) }
            }
            .glassEffect(isOn ? .identity : .regular.interactive(), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .animation(Motion.spring, value: isOn)
        .sensoryFeedback(.impact(weight: .light), trigger: isOn)
        .accessibilityLabel(Text(L10n.issuesMeTooAccessibility))
        .accessibilityValue(Text(count, format: .number))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Pictures

/// The photos on a problem, as a swipeable strip.
///
/// Nothing explains a leak like a picture of it, and a plumber asked over the
/// phone will ask for one. Paged rather than a grid: on a phone a 16:9 photo of
/// a stain is unreadable at thumbnail size, and there are never more than six.
public struct IssuePhotoStrip: View {
    private let photos: [IssuePhotoRef]
    private let height: CGFloat
    /// Handed the *storage id*, not the URL: deleting a picture is a write, and
    /// a signed URL is not an identity.
    private let onDelete: ((String) -> Void)?

    @State private var index = 0

    public init(
        photos: [IssuePhotoRef],
        height: CGFloat = 210,
        onDelete: ((String) -> Void)? = nil
    ) {
        self.photos = photos
        self.height = height
        self.onDelete = onDelete
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $index) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { position, photo in
                    RemoteImage(
                        url: URL(string: photo.url),
                        targetSize: CGSize(width: 400, height: height)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipped()
                    .tag(position)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if photos.count > 1 {
                // The system page dots sit on an opaque bar that fights the
                // glass, so the strip draws its own on a capsule of it.
                HStack(spacing: 5) {
                    ForEach(photos.indices, id: \.self) { position in
                        Circle()
                            .fill(position == index ? Color.white : Color.white.opacity(0.45))
                            .frame(width: position == index ? 7 : 5, height: position == index ? 7 : 5)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .glassOverlay(cornerRadius: 20)
                .padding(.bottom, 10)
                .animation(Motion.spring, value: index)
            }
        }
        .frame(height: height)
        .clipShape(.rect(cornerRadius: Metrics.cardRadius, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if let onDelete, photos.indices.contains(index) {
                Button(role: .destructive) { onDelete(photos[index].id) } label: {
                    Image(systemName: "trash.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .contentShape(.circle)
                }
                .buttonStyle(.pressable)
                .background(.black.opacity(0.35), in: .circle)
                .padding(10)
                .accessibilityLabel(Text(L10n.issuesPhotoRemove))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(L10n.issuesPhotosAccessibility(photos.count)))
    }
}

// MARK: - Getting a photo onto the wire

/// Turns whatever the photo picker handed over into something worth uploading.
///
/// A modern phone photo is a twelve-megapixel HEIC of several megabytes, and
/// what this feature needs is "a picture of the leak" — legible on a phone
/// screen, over a household's wifi, on a plan somebody pays for. Downsampling to
/// 2000px on the long edge and re-encoding as JPEG turns four megabytes into
/// about three hundred kilobytes with no visible difference at the size it is
/// ever drawn, and it also normalises HEIC, which not every viewer of a signed
/// storage URL can decode.
///
/// The orientation is baked in rather than left in the EXIF: a photo taken
/// sideways is stored sideways, so no consumer has to remember to honour a tag.
public enum IssuePhoto {
    /// The longest edge an uploaded photo keeps.
    public static let maxEdge: CGFloat = 2000
    /// Well past where JPEG artefacts are visible on a photograph.
    public static let quality: CGFloat = 0.8

    public static func encode(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }

        let scale = min(1, maxEdge / longest)
        let target = CGSize(
            width: (image.size.width * scale).rounded(),
            height: (image.size.height * scale).rounded()
        )

        // `UIGraphicsImageRenderer` draws in the orientation the image reports,
        // so the result is upright with no EXIF tag left to interpret.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: quality)
    }
}
