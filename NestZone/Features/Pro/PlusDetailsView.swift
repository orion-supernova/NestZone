import SwiftUI

/// Everything Plus includes, and what a house without it keeps.
///
/// A plain page of facts, pushed onto the paywall's stack and onto Settings'
/// (never a sheet over either, so the paywall is never lost): glass cards on
/// the Backdrop, one row per feature that VoiceOver reads as a single
/// element. It animates nothing and holds no state; the page reads what it is
/// handed, so it is the same for a free house and a Plus one.
struct PlusDetailsView: View {
    let status: ProStatus
    let homeNames: [HomeID: String]

    @Environment(\.theme) private var theme

    private static let freeRows: [(symbol: String, text: LocalizedStringResource)] = [
        ("book.closed.fill", L10n.plusFreeReadable),
        ("checklist", L10n.plusFreeTasks),
        ("note.text", L10n.plusFreeNotes),
        ("fork.knife", L10n.plusFreeRecipes),
        ("popcorn.fill", L10n.plusFreeMovies),
        ("leaf.fill", L10n.plusFreeNestie),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                PlusLockup(tileSize: 40, font: .system(.title3, design: .rounded, weight: .bold))
                Text(L10n.plusDetailsSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondaryText)

                ForEach(PlusDetail.groups) { group in
                    section(group)
                }
                free
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.vertical, Metrics.stackSpacing)
        }
        .background(Backdrop(tint: theme.accent))
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(Text(L10n.plusDetailsTitle))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ group: PlusDetailGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.title)
                .groupLabel()
                .accessibilityAddTraits(.isHeader)
            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(group.details) { detail in
                        row(detail)
                    }
                }
            }
        }
    }

    private func row(_ detail: PlusDetail) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: detail.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(detail.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(detail.title).font(.subheadline.weight(.semibold))
                Text(detail.text)
                    .font(.footnote)
                    .foregroundStyle(.secondaryText)
                if detail.feature == .multipleHomes, let line = status.coverageLine(homeNames: homeNames) {
                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(.secondaryText)
                        .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var free: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.plusFreeTitle)
                .groupLabel()
                .accessibilityAddTraits(.isHeader)
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Self.freeRows.indices, id: \.self) { index in
                        let row = Self.freeRows[index]
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: row.symbol)
                                .font(.subheadline)
                                .foregroundStyle(Palette.success)
                                .frame(width: 28)
                                .accessibilityHidden(true)
                            Text(row.text).font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}
