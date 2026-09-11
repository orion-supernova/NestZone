#if DEBUG
import SwiftUI
import UIKit

/// A bench for the merged-glass list — the row style Tasks, Issues, Home, Hub
/// and Movie Night all share, each with a different `GlassGroup` spacing and
/// none of them with a preview to check it in.
///
/// The look is decided by the container's `spacing` against the gap between the
/// rows — but not in the way the obvious reading suggests. Measured on this
/// bench, iPhone 17, iOS 26.5:
///
/// | spacing | row gap | result                        |
/// |--------:|--------:|-------------------------------|
/// |      24 |      12 | separate cards                |
/// |      24 |      11 | separate cards                |
/// |      24 |       8 | merged, pinched at each join  |
/// |      24 |       2 | merged                        |
/// |      60 |      12 | merged                        |
/// |      60 |       2 | merged, barely a neck left    |
///
/// So the rows fuse when the gap is somewhere around a *third* of the spacing
/// or less, not merely less than it. Which means the thing worth knowing about
/// this app: **Tasks, Home and Hub do not actually merge.** They ship spacing
/// 24 over a 12pt gap, which is the first row of that table — a `GlassGroup`
/// that costs a container and buys separate cards. Only Messages (spacing 0-4
/// over touching bubbles) is anywhere near the fusing side.
///
/// Strings here are literals on purpose. This never ships in a build a person
/// can open, so putting throwaway copy in the String Catalog would only give
/// `L10n` cases nobody can delete later.
struct GlassListLab: View {

    // MARK: - Merge

    @State private var containerSpacing = Double(GlassListStyle.default.containerSpacing)
    @State private var rowGap = Double(GlassListStyle.default.rowGap)
    @State private var unionsRows = false
    /// Whether the rows sit in a `GlassEffectContainer` at all.
    ///
    /// Off is not an idle curiosity: it is what a `List`-based screen looks
    /// like, because a container cannot span List cells. It is also the only
    /// way to see a tilt — see `TiltMode`.
    @State private var usesContainer = true

    // MARK: - Row

    @State private var cornerRadius = Double(GlassListStyle.default.rowRadius)
    @State private var rowPaddingV = Double(GlassListStyle.default.rowPaddingV)
    @State private var rowPaddingH = Double(GlassListStyle.default.rowPaddingH)
    @State private var sidePadding = Double(Metrics.screenPadding)
    @State private var rowCount: Double = 7

    // MARK: - Surface

    @State private var tintStrength: Double = 0
    @State private var isInteractive = GlassListStyle.default.rowInteractive
    @State private var isClear = false
    /// A resting angle for the whole row, the way `StickyNote` pins a note.
    /// Negative lifts the right-hand side. Zero is the shipped behaviour.
    @State private var tilt: Double = 0
    @State private var tiltMode: TiltMode = .uniform

    // MARK: - Stage

    @State private var theme: AppTheme = .basic
    @State private var scheme: ColorScheme = .light
    @State private var stage: Stage = .wash
    @State private var showsPanel = true
    @State private var copied = false

    /// Two namespaces on purpose. `glassEffectID` is morph identity and
    /// `glassEffectUnion` is grouping; sharing one namespace makes a row both
    /// its own morph target and a member of a union under the same id space,
    /// which is exactly the kind of ambiguity that shows up as a merge that
    /// will not change when you move the slider.
    @Namespace private var glass
    @Namespace private var unions

    /// The very value the app ships, assembled from the sliders. What you tune
    /// here is what `GlassListStyle.default` would be if you pasted these five
    /// numbers into it — no second copy of the geometry to keep in step.
    private var style: GlassListStyle {
        GlassListStyle(
            containerSpacing: CGFloat(containerSpacing),
            rowGap: CGFloat(rowGap),
            rowRadius: CGFloat(cornerRadius),
            rowPaddingH: CGFloat(rowPaddingH),
            rowPaddingV: CGFloat(rowPaddingV),
            rowInteractive: isInteractive
        )
    }

    var body: some View {
        ZStack {
            stage.view(tint: theme.accent)

            ScrollView {
                rowStack {
                    ForEach(rows) { row in
                        LabRow(
                            row: row,
                            tint: tintStrength > 0
                                ? theme.accent.opacity(tintStrength)
                                : nil,
                            interactive: isInteractive,
                            clear: isClear
                        )
                        .rotationEffect(.degrees(tiltMode.angle(tilt, row: row.id)))
                        .glassEffectID(row.id, in: glass)
                        .glassEffectUnion(
                            // Distinct ids when the toggle is off, so the
                            // modifier stays put and only its value changes —
                            // adding and removing it instead would re-identify
                            // the row on every toggle.
                            id: unionsRows ? "rows" : "row-\(row.id)",
                            namespace: unions
                        )
                    }
                }
                .padding(.horizontal, CGFloat(sidePadding))
                .padding(.vertical, 24)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .animation(Motion.spring, value: containerSpacing)
            .animation(Motion.spring, value: rowGap)
            .animation(Motion.spring, value: cornerRadius)
            .animation(Motion.spring, value: unionsRows)
        }
        // The animations belong to the list and stop there. Applied out here
        // they also covered the panel, and an implicit animation above a
        // `Slider` is what made the sliders climb but never come back: the
        // thumb animates towards each new value while the drag is still
        // measuring against where it used to be, so every leftward pull is
        // eaten by the animation chasing the rightward one.
        .safeAreaInset(edge: .bottom, spacing: 0) { panel }
        .appTheme(theme)
        .preferredColorScheme(scheme)
    }

    /// The tuned value as source, for the pasteboard and the console. The bench
    /// is only useful if what you land on can leave it.
    private var styleSource: String {
        """
        GlassListStyle(
            containerSpacing: \(Int(containerSpacing)),
            rowGap: \(Int(rowGap)),
            rowRadius: \(Int(cornerRadius)),
            rowPaddingH: \(Int(rowPaddingH)),
            rowPaddingV: \(Int(rowPaddingV)),
            rowInteractive: \(isInteractive)
        )\(tilt != 0 ? "\n// plus a \(tilt)° resting tilt, \(tiltMode.label) — not part of the style" : "")
        """
    }

    /// The rows, in a glass container or not.
    ///
    /// `GlassList` when the container is on, a plain `VStack` when it is off —
    /// which is what Recipes, Tasks and Shopping are now that their rows live
    /// in a `List`.
    @ViewBuilder
    private func rowStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if usesContainer {
            GlassList(style: style, content: content)
        } else {
            VStack(spacing: CGFloat(rowGap), content: content)
        }
    }

    /// What the current angle costs in vertical space.
    ///
    /// `rotationEffect` turns the drawing, not the layout: the row keeps its
    /// axis-aligned slot, so a rotated row needs `width · sin(angle)` more room
    /// than it has. At the house width that is about 6pt per degree — which is
    /// why an 8pt gap is gone by 1.3° and the rows start overlapping.
    private var tiltCost: String {
        guard tilt != 0 else { return "" }
        guard !usesContainer else {
            return " · tilt ignored: a glass container flattens it"
        }
        let width = 393 - CGFloat(sidePadding) * 2
        let needed = Double(width) * abs(sin(tilt * .pi / 180))
        let verdict = needed > rowGap ? "overlaps" : "fits"
        return " · \(Int(tilt))° needs \(Int(needed))pt of gap, has \(Int(rowGap)) — \(verdict)"
    }

    /// The sentence the sliders are really editing. The threshold here is
    /// measured, not documented: at spacing 24 the rows fuse at a gap of 8 and
    /// stay apart at 11, and 60/12 fuses, which puts the flip near a third of
    /// the spacing. Treat it as a signpost — the picture above is the truth.
    private var verdict: String {
        if unionsRows {
            "union on — one shape whatever the distance"
        } else if rowGap <= containerSpacing / 3 {
            "gap \(Int(rowGap)) ≤ spacing \(Int(containerSpacing)) ÷ 3 — should fuse" + tiltCost
        } else {
            "gap \(Int(rowGap)) of spacing \(Int(containerSpacing)) — separate cards" + tiltCost
        }
    }

    private var rows: [LabRow.Model] { Array(LabRow.Model.sample.prefix(Int(rowCount))) }

    // MARK: - Control panel

    private var panel: some View {
        VStack(spacing: 0) {
            HStack {
                Text(verdict)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                Spacer(minLength: 8)
                Button {
                    showsPanel.toggle()
                } label: {
                    Image(systemName: showsPanel ? "chevron.down" : "chevron.up")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if showsPanel {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        group("Merge") {
                            knob("container spacing", $containerSpacing, 0...48)
                            knob("row gap", $rowGap, 0...32)
                            Toggle("union all rows into one shape", isOn: $unionsRows)
                            Toggle("glass container (off = a List screen)", isOn: $usesContainer)
                        }

                        group("Row") {
                            knob("corner radius", $cornerRadius, 0...32)
                            knob("padding — vertical", $rowPaddingV, 0...28)
                            knob("padding — horizontal", $rowPaddingH, 0...28)
                            knob("side padding", $sidePadding, 0...48)
                            knob("row count", $rowCount, 1...12, step: 1)
                        }

                        group("Surface") {
                            knob("accent tint", $tintStrength, 0...0.6, step: 0.02)
                            // The range goes far past anything usable on
                            // purpose: `rotationEffect` has no limit, but the
                            // row's *slot* does not rotate with it, so a full
                            // width row eats its gap fast. See `tiltCost`.
                            knob("tilt — resting angle", $tilt, -45...45, step: 0.5)
                            labelled("tilt applies") {
                                Picker("", selection: $tiltMode) {
                                    ForEach(TiltMode.allCases, id: \.self) { mode in
                                        Text(mode.label).tag(mode)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                            }
                            Toggle("interactive — the row leans to the touch", isOn: $isInteractive)
                            Toggle("clear instead of regular", isOn: $isClear)
                        }

                        group("Stage") {
                            // Labelled by hand: outside a `Form` a `Picker`'s
                            // own label is dropped, so every one of these read
                            // as an unexplained control.
                            labelled("theme") {
                                Picker("", selection: $theme) {
                                    ForEach(AppTheme.allCases) { theme in
                                        Text(theme.rawValue).tag(theme)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                            labelled("backdrop") {
                                Picker("", selection: $stage) {
                                    ForEach(Stage.allCases, id: \.self) { stage in
                                        Text(stage.label).tag(stage)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                            }
                            labelled("appearance") {
                                Picker("", selection: $scheme) {
                                    Text("light").tag(ColorScheme.light)
                                    Text("dark").tag(ColorScheme.dark)
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                            }
                        }

                        HStack {
                            Button("GlassListStyle.default") { apply(.default) }
                            Spacer()
                            Button(".cards") { apply(.cards) }
                        }

                        // The simulator's pasteboard is shared with the Mac, so
                        // `xcrun simctl pbpaste booted` reads this straight out
                        // — no screenshotting the panel to find out what the
                        // sliders ended up on.
                        Button {
                            UIPasteboard.general.string = styleSource
                            print("[GlassListLab] tuned style:\n" + styleSource)
                            copied = true
                        } label: {
                            Label {
                                Text(copied ? "copied — paste over .default" : "copy as GlassListStyle")
                            } icon: {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.caption.weight(.medium))
                        .onChange(of: styleSource) { copied = false }
                        .font(.caption.weight(.medium))
                        .buttonStyle(.bordered)
                    }
                    .padding(16)
                }
                .frame(height: 320)
            }
        }
        .font(.caption)
        .background(.bar)
    }

    @ViewBuilder
    private func group<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
            content()
        }
    }

    /// A control under the same title column as the sliders, so the panel reads
    /// as one list rather than as knobs plus a pile of loose controls.
    private func labelled<Control: View>(
        _ title: String, @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 10) {
            Text(title).frame(width: 130, alignment: .leading)
            control()
            Spacer(minLength: 0)
        }
    }

    /// One labelled slider that shows its own value, so the number under the
    /// thumb is the number you would paste into `Metrics`.
    ///
    /// Every knob is a `Double`, including the ones that end up as `CGFloat`
    /// geometry — one binding type, one overload, nothing for the type checker
    /// to choose between.
    private func knob(
        _ title: String,
        _ value: Binding<Double>,
        _ range: ClosedRange<Double>,
        step: Double = 1
    ) -> some View {
        HStack(spacing: 10) {
            Text(title).frame(width: 130, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(String(format: step < 1 ? "%.2f" : "%.0f", value.wrappedValue))
                .monospacedDigit()
                .frame(width: 38, alignment: .trailing)
        }
    }

    /// The two styles the app actually has, so the bench can flip between the
    /// house list and the separate-cards fallback rather than between numbers
    /// somebody typed once.
    private func apply(_ preset: GlassListStyle) {
        containerSpacing = Double(preset.containerSpacing)
        rowGap = Double(preset.rowGap)
        cornerRadius = Double(preset.rowRadius)
        rowPaddingH = Double(preset.rowPaddingH)
        rowPaddingV = Double(preset.rowPaddingV)
        sidePadding = Double(Metrics.screenPadding)
        tintStrength = 0
        unionsRows = false
        isInteractive = preset.rowInteractive
        isClear = false
        tilt = 0
        tiltMode = .uniform
        usesContainer = true
    }

    /// Glass only shows itself against something worth refracting; a flat
    /// background makes every setting here look identical.
    private enum Stage: CaseIterable {
        case plain, wash, busy

        /// A literal `0..<7` inside a `ForEach` is a warning in a preview
        /// build: the thunk rewrites the bounds, and a non-constant range is
        /// only legal over an explicit identity.
        static let blobs = Array(0..<7)

        var label: String {
            switch self {
            case .plain: "plain"
            case .wash: "wash"
            case .busy: "busy"
            }
        }

        /// `@MainActor` because `Backdrop` is a `View` and so is main-actor
        /// isolated; a plain `func` returning one is a concurrency warning.
        @MainActor @ViewBuilder
        func view(tint: Color) -> some View {
            switch self {
            case .plain:
                Color(.systemBackground).ignoresSafeArea()
            case .wash:
                Backdrop(tint: tint)
            case .busy:
                ZStack {
                    Color(.systemBackground)
                    ForEach(Self.blobs, id: \.self) { index in
                        Circle()
                            .fill(index.isMultiple(of: 2) ? tint : Palette.amber)
                            .frame(width: 190)
                            .offset(
                                x: index.isMultiple(of: 3) ? -110 : 120,
                                y: CGFloat(index) * 150 - 260
                            )
                            .blur(radius: 40)
                            .opacity(0.55)
                    }
                }
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - The row under test

/// A stand-in for `TaskListRow`, which is private to `TasksView` and hard-codes
/// the geometry this bench exists to question. Same structure, same fonts —
/// only the numbers are bindings.
private struct LabRow: View {
    struct Model: Identifiable {
        let id: String
        let title: String
        let kind: String
        let symbol: String
        let assignee: String
        let due: String
        let badge: (String, Color)?
        let isDone: Bool

        static let sample: [Model] = [
            .init(id: "1", title: "Take the bins out", kind: "Chore",
                  symbol: "trash", assignee: "Murat", due: "in 2 hours",
                  badge: ("High", Palette.hotPink), isDone: false),
            .init(id: "2", title: "Descale the kettle before it starts tasting like a coin",
                  kind: "Kitchen", symbol: "drop", assignee: "Ada",
                  due: "tomorrow", badge: nil, isDone: false),
            .init(id: "3", title: "Water the plants", kind: "Chore",
                  symbol: "leaf", assignee: "Murat", due: "yesterday",
                  badge: ("Low", Palette.cyan), isDone: false),
            .init(id: "4", title: "Book the boiler service", kind: "Admin",
                  symbol: "wrench.and.screwdriver", assignee: "Ada",
                  due: "next week", badge: nil, isDone: true),
            .init(id: "5", title: "Hoover the stairs", kind: "Chore",
                  symbol: "wind", assignee: "Murat", due: "in 3 days",
                  badge: nil, isDone: false),
            .init(id: "6", title: "Return the parcel", kind: "Errand",
                  symbol: "shippingbox", assignee: "Ada", due: "in 5 days",
                  badge: ("High", Palette.hotPink), isDone: false),
            .init(id: "7", title: "Change the bed sheets", kind: "Chore",
                  symbol: "bed.double", assignee: "Murat", due: "Sunday",
                  badge: nil, isDone: true),
            .init(id: "8", title: "Pay the internet bill", kind: "Money",
                  symbol: "wifi", assignee: "Ada", due: "in 9 days",
                  badge: nil, isDone: false),
            .init(id: "9", title: "Fix the wobbly shelf", kind: "Repair",
                  symbol: "hammer", assignee: "Murat", due: "someday",
                  badge: ("Low", Palette.cyan), isDone: false),
            .init(id: "10", title: "Defrost the freezer", kind: "Kitchen",
                  symbol: "snowflake", assignee: "Ada", due: "in 2 weeks",
                  badge: nil, isDone: false),
            .init(id: "11", title: "Wash the windows", kind: "Chore",
                  symbol: "square.split.diagonal.2x2", assignee: "Murat",
                  due: "in 3 weeks", badge: nil, isDone: false),
            .init(id: "12", title: "Sort the recycling", kind: "Chore",
                  symbol: "arrow.3.trianglepath", assignee: "Ada",
                  due: "Friday", badge: nil, isDone: true),
        ]
    }

    /// Named, so the comparison preview's body stays free of generic slicing.
    static let first3 = Array(Model.sample.prefix(3))

    @Environment(\.glassListStyle) private var style

    let row: Model
    let tint: Color?
    let interactive: Bool
    let clear: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.isDone ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(row.isDone ? Palette.success : Color.secondary)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(row.isDone, color: .secondary)
                    .foregroundStyle(row.isDone ? .secondary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Label { Text(row.kind) } icon: { Image(systemName: row.symbol) }
                    Text(row.assignee)
                    Text(row.due)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if let badge = row.badge, !row.isDone {
                Badge(badge.0, tint: badge.1)
            }
        }
        .padding(.horizontal, style.rowPaddingH)
        .padding(.vertical, style.rowPaddingV)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(LabSurface(
            cornerRadius: style.rowRadius, tint: tint,
            interactive: interactive, clear: clear
        ))
    }
}

/// How a resting tilt is spread across the rows.
///
/// `Glass` has no tilt of its own — it offers `regular`/`clear`, `tint` and
/// `interactive`, and nothing for how the surface sits — so this is a plain
/// `rotationEffect`, the same trick `StickyNote` uses to make a note look
/// pinned rather than printed. Negative angles lift the right-hand side.
///
/// **It does nothing inside a `GlassEffectContainer`.** The container renders
/// its shapes in its own space and discards a child's transform, so a row in a
/// `GlassList` cannot be tilted at all — measured on the bench, 4° with the
/// container on draws perfectly level rows and 4° with it off draws what you
/// would expect. Tilt is therefore only available to the `List`-based screens,
/// which have no container: Recipes, Tasks, Shopping.
private enum TiltMode: CaseIterable {
    /// Every row at the same angle: the list reads as one slanted sheet.
    case uniform
    /// Alternating sides, so consecutive rows lean into each other.
    case alternate
    /// A seeded angle per row, `StickyNote`'s approach: the same row keeps its
    /// angle across redraws, and no two neighbours match.
    case scattered

    var label: String {
        switch self {
        case .uniform: "every row"
        case .alternate: "alternating"
        case .scattered: "scattered"
        }
    }

    func angle(_ degrees: Double, row id: String) -> Double {
        guard degrees != 0 else { return 0 }
        switch self {
        case .uniform:
            return degrees
        case .alternate:
            return restingTilt(seed: id, spread: 1) < 0 ? degrees : -degrees
        case .scattered:
            return restingTilt(seed: id, spread: degrees)
        }
    }
}

/// One `glassEffect` call, never a branch. An `if clear { … } else { … }` here
/// swaps the view's structural identity every time the toggle moves, which
/// tears the row down and rebuilds it — the glass restarts instead of morphing,
/// and any in-flight merge animation is lost. Composing the style as a value
/// keeps one code path that simply re-renders.
private struct LabSurface: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool
    let clear: Bool

    private var glass: Glass {
        (clear ? Glass.clear : Glass.regular)
            .tint(tint)
            .interactive(interactive)
    }

    func body(content: Content) -> some View {
        content.glassEffect(glass, in: .rect(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Previews

#Preview("Glass list lab") {
    GlassListLab()
}

/// The two styles the app ships, as data rather than as literals inside the
/// preview — Xcode rewrites every literal in a preview body into a
/// `__designTimeInteger(_:fallback:)` call, and an array of tuples built out of
/// those is what timed the type-checker out here once already.
private struct SpacingSample: Identifiable {
    let id: String
    let style: GlassListStyle

    static let shipping: [SpacingSample] = [
        SpacingSample(id: "GlassListStyle.default — gap 8, merges", style: .default),
        SpacingSample(id: "GlassListStyle.cards — gap 12, separate", style: .cards),
    ]
}

private struct SpacingSampleStack: View {
    let sample: SpacingSample

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sample.id)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Metrics.screenPadding)

            GlassList(style: sample.style) {
                ForEach(LabRow.first3) { row in
                    LabRow(row: row, tint: nil, interactive: false, clear: false)
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
        }
    }
}

/// Both house styles over the same rows, so the difference is a glance.
#Preview("Shipping styles") {
    ScrollView {
        VStack(spacing: 28) {
            ForEach(SpacingSample.shipping) { sample in
                SpacingSampleStack(sample: sample)
            }
        }
        .padding(.vertical, 24)
    }
    .background(Backdrop(tint: AppTheme.basic.accent))
}
#endif
