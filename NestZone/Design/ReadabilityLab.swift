#if DEBUG
import SwiftUI

/// A Today-shaped screen built from the shared components, for reading the
/// app's type and colour roles in every theme without signing in.
///
///   xcrun simctl launch booted com.walhallaa.NestZone -readabilityLab -appTheme neonNight
///   xcrun simctl ui booted appearance dark
///
/// The top half is the real components and the new roles (what a change to
/// them moves);
/// the "system roles" strip at the foot is raw `.secondary`, `.tertiary` and
/// the accent, left as they are on purpose so a before and an after of the
/// same theme have something fixed to be read against.
///
/// Debug-only, so its copy is literal and stays out of the String Catalog.
struct ReadabilityLab: View {
    @State private var selected = 0

    private var theme: AppTheme {
        UserDefaults.standard.string(forKey: "appTheme").flatMap(AppTheme.init(rawValue:)) ?? .basic
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                section("Needs you") {
                    GlassList {
                        row("Internet is 3 days late", "Due Friday · shared with 3 people", badge: ("Overdue", Palette.danger))
                        row("Put the bins out", "Tonight · Zeynep", badge: ("Chore", Palette.statTasks))
                    }
                }
                section("Up next") {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(verbatim: "Movie night").font(.headline)
                            Text(verbatim: "Saturday 20:00 · Living room").font(.subheadline).foregroundStyle(.secondaryText)
                            Text(verbatim: "Four people said yes, nobody has picked a film.")
                                .font(.footnote).foregroundStyle(.tertiaryText)
                            HStack {
                                Chip("All", isSelected: selected == 0) { selected = 0 }
                                Chip("Mine", symbol: "person", isSelected: selected == 1) { selected = 1 }
                                Chip("Done", isSelected: selected == 2) { selected = 2 }
                            }
                        }
                    }
                }
                HStack(spacing: 12) {
                    StatTile(title: "Shopping", value: 7, change: 2, symbol: "cart", tint: Palette.statShopping)
                    StatTile(title: "Messages", value: 12, change: -1, symbol: "bubble.left", tint: Palette.statMessages)
                }
                PrimaryButton("Add anything", symbol: "plus") {}
                SecondaryButton("Not now") {}
                EmptyStateView(title: "All clear", message: "Nothing needs you today.", symbol: "checkmark.circle", isCompact: true)
                section("Status words") { statusWords }
                section("Chips on a tint and on the accent") { selectedChips }
                section("Sticky notes") { stickyNotes }
                section("Accent buttons") { accentButtons }
                systemRoles
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.bottom, Metrics.scrollBottomInset)
        }
        .background(Backdrop(tint: theme.accent))
        .appTheme(theme)
    }

    /// The words that used to be drawn in a tint (green, orange, red): the
    /// measured text colours, with the tint left on the glyph.
    private var statusWords: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label { Text(verbatim: "You are owed 42.00") } icon: { Image(systemName: "arrow.down.left.circle.fill") }
                    .foregroundStyle(Palette.successText)
                Label { Text(verbatim: "Over the estimate by 15.00") } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                    .foregroundStyle(Palette.warningText)
                Label { Text(verbatim: "Didn't go through") } icon: { Image(systemName: "exclamationmark.circle.fill") }
                    .foregroundStyle(Palette.dangerText)
                Text(verbatim: "Event kind: words primary, glyph in its tint")
                    .font(.footnote)
                    .foregroundStyle(.secondaryText)
            }
            .font(.footnote.weight(.medium))
        }
    }

    private var selectedChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach([("Food", Palette.eventFood), ("Party", Palette.eventParty), ("Holiday", Palette.eventHoliday)], id: \.0) { item in
                    HStack(spacing: 5) {
                        Image(systemName: "circle.fill").font(.caption2).foregroundStyle(item.1)
                        Text(verbatim: item.0).font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .foregroundStyle(.primary)
                    .background(item.1.opacity(0.3), in: .capsule)
                }
            }
            HStack(spacing: 8) {
                Text(verbatim: "On the accent").font(.caption.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .foregroundStyle(theme.onAccent)
                    .background(theme.accent, in: .capsule)
                Text(verbatim: "Accent as ink").font(.caption.weight(.semibold))
                    .foregroundStyle(.accentText)
            }
        }
    }

    /// Ink on the seven swatches: the author line and the timestamp.
    private var stickyNotes: some View {
        HStack(spacing: 10) {
            ForEach([Palette.paperYellow, Palette.paperRed, Palette.paperPurple, Palette.paperBlue], id: \.self) { paper in
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: "Milk, eggs").font(.system(.subheadline, design: .rounded, weight: .medium)).foregroundStyle(Palette.paperInk)
                    Text(verbatim: "— Zeynep").font(.system(.caption, design: .rounded, weight: .medium)).foregroundStyle(Palette.paperInkSecondary)
                    Text(verbatim: "2 min ago").font(.system(.caption2, design: .rounded)).foregroundStyle(Palette.paperInkTertiary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(paper, in: .rect(cornerRadius: 6))
            }
        }
    }

    private var accentButtons: some View {
        VStack(spacing: 10) {
            Button { } label: { Text(verbatim: "Celebrate").font(.subheadline.weight(.semibold)).foregroundStyle(.onAccent).frame(maxWidth: .infinity) }
                .buttonStyle(.glassProminent).tint(theme.accent)
            Button { } label: { Text(verbatim: "Mark fixed").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity) }
                .buttonStyle(.glassProminent).tint(Palette.answerYes)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "Tuesday evening · Hi Murat").font(.subheadline.weight(.semibold)).foregroundStyle(.secondaryText)
            Text(verbatim: "Internet is 3 days late · 2 chores")
                .font(.system(.title2, design: .rounded, weight: .bold))
        }
        .padding(.top, 8)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title).groupLabel().padding(.leading, 4)
            content()
        }
    }

    private func row(_ title: String, _ detail: String, badge: (String, Color)) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(.subheadline.weight(.medium))
                Text(verbatim: detail).font(.footnote).foregroundStyle(.secondaryText)
            }
            Spacer(minLength: 0)
            Badge(badge.0, tint: badge.1)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Palette.accessory)
        }
        .glassRow()
    }

    /// Raw system roles, unchanged by the design system.
    private var systemRoles: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: "System roles (reference)").font(.footnote.weight(.semibold))
                Text(verbatim: "Color.primary").font(.subheadline)
                Text(verbatim: "Color.secondary").font(.subheadline).foregroundStyle(Color.secondary)
                Text(verbatim: "HierarchicalShapeStyle.tertiary").font(.subheadline).foregroundStyle(.tertiary)
                Text(verbatim: "HierarchicalShapeStyle.quaternary").font(.subheadline).foregroundStyle(.quaternary)
                Text(verbatim: "theme.accent as text").font(.subheadline).foregroundStyle(theme.accent)
                Text(verbatim: "Caption 2, secondary").font(.caption2).foregroundStyle(Color.secondary)
            }
        }
    }
}

/// The same page drawn the way the app drew it before the text roles: system
/// `.secondary` and `.tertiary`, the accent as text, white on the accent, tint
/// as text in the badges, the stronger wash and no glass floor. Kept so a
/// before and an after of any change to the roles can be taken from one
/// build:  `-readabilityLab -readabilityLegacy`.
struct LegacyReadabilityLab: View {
    @State private var selected = 0
    @Environment(\.colorScheme) private var scheme

    private var theme: AppTheme {
        UserDefaults.standard.string(forKey: "appTheme").flatMap(AppTheme.init(rawValue:)) ?? .basic
    }

    private var card: Glass { .regular }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "Tuesday evening · Hi Murat").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Text(verbatim: "Internet is 3 days late · 2 chores")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                }
                .padding(.top, 8)
                group("Needs you") {
                    GlassEffectContainer(spacing: 15) {
                        VStack(spacing: 8) {
                            row("Internet is 3 days late", "Due Friday · shared with 3 people", "Overdue", .red)
                            row("Put the bins out", "Tonight · Zeynep", "Chore", Palette.statTasks)
                        }
                    }
                }
                group("Up next") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(verbatim: "Movie night").font(.headline)
                        Text(verbatim: "Saturday 20:00 · Living room").font(.subheadline).foregroundStyle(.secondary)
                        Text(verbatim: "Four people said yes, nobody has picked a film.").font(.footnote).foregroundStyle(.tertiary)
                        HStack {
                            chip("All", 0); chip("Mine", 1); chip("Done", 2)
                        }
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(card, in: .rect(cornerRadius: 20, style: .continuous))
                }
                HStack(spacing: 12) {
                    StatTile(title: "Shopping", value: 7, change: 2, symbol: "cart", tint: Palette.statShopping)
                    StatTile(title: "Messages", value: 12, change: -1, symbol: "bubble.left", tint: Palette.statMessages)
                }
                Button { } label: {
                    Label { Text(verbatim: "Add anything").font(.body.weight(.semibold)) } icon: { Image(systemName: "plus") }
                        .frame(maxWidth: .infinity).frame(minHeight: 26)
                }
                .buttonStyle(.glassProminent).controlSize(.large).tint(theme.accent)
                Button { } label: {
                    Text(verbatim: "Not now").font(.body.weight(.medium)).frame(maxWidth: .infinity).frame(minHeight: 26)
                }
                .buttonStyle(.glass).controlSize(.large)
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "theme.accent as text").font(.subheadline).foregroundStyle(theme.accent)
                    Text(verbatim: "Caption 2, secondary").font(.caption2).foregroundStyle(Color.secondary)
                    Text(verbatim: "Quaternary").font(.subheadline).foregroundStyle(.quaternary)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(card, in: .rect(cornerRadius: 20, style: .continuous))
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.bottom, Metrics.scrollBottomInset)
        }
        .background(
            LinearGradient(colors: [theme.accent.opacity(scheme == .dark ? 0.26 : 0.14), .clear], startPoint: .top, endPoint: .center)
                .background(Color(.systemBackground)).ignoresSafeArea()
        )
        .appTheme(theme)
    }

    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                .textCase(.uppercase).padding(.leading, 4)
            content()
        }
    }

    private func row(_ title: String, _ detail: String, _ badge: String, _ tint: Color) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(.subheadline.weight(.medium))
                Text(verbatim: detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(verbatim: badge).font(.caption.weight(.semibold)).foregroundStyle(tint)
                .padding(.horizontal, 9).padding(.vertical, 4).background(tint.opacity(0.15), in: .capsule)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.35))
        }
        .padding(.horizontal, 16).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(card.interactive(), in: .rect(cornerRadius: 32, style: .continuous))
    }

    private func chip(_ title: String, _ index: Int) -> some View {
        let on = selected == index
        return Button { selected = index } label: {
            Text(verbatim: title).font(.subheadline.weight(.medium))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(on ? Color.white : Color.primary)
                .background { if on { Capsule().fill(theme.accent) } }
                .glassEffect(on ? .identity : .regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }
}
#endif
