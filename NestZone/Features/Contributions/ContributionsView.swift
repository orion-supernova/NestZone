import ComposableArchitecture
import SwiftUI

public struct ContributionsView: View {
    @Bindable var store: StoreOf<ContributionsFeature>

    @Environment(\.theme) private var theme

    public init(store: StoreOf<ContributionsFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: Metrics.sectionSpacing) {
                windowPicker

                if store.isLoading {
                    loading
                } else if store.data.isEmpty {
                    empty
                } else {
                    splitCard.appear(0)
                    verdictCard.appear(1)
                    leaderboard.appear(2)
                    activity.appear(3)
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.bottom, Metrics.scrollBottomInset)
        }
        .background(Backdrop(tint: theme.accent))
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(Text(L10n.contributionsScreenTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .animation(Motion.spring, value: store.data)
    }

    private var windowPicker: some View {
        Picker(selection: $store.window) {
            ForEach(ContributionWindow.allCases) { window in
                Text(window.title).tag(window)
            }
        } label: { EmptyView() }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var loading: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            Circle()
                .fill(.quaternary)
                .frame(width: 180, height: 180)
            SkeletonList(rows: 3, height: 56)
        }
        .padding(.top, 24)
        .redacted(reason: .placeholder)
    }

    private var empty: some View {
        EmptyStateView(
            title: L10n.contributionsEmptyTitle,
            message: L10n.contributionsEmptyMessage,
            symbol: "chart.pie",
            isCompact: true
        )
        .padding(.top, 40)
    }

    // MARK: - Split

    /// The ring plus its legend. The one thing someone opens this screen for.
    private var splitCard: some View {
        GlassCard(padding: 20) {
            VStack(spacing: 18) {
                ContributionDonut(
                    slices: store.data.slices,
                    total: store.data.totalCompleted,
                    caption: L10n.contributionsDonutCaption
                )
                .frame(maxWidth: .infinity)

                ContributionLegend(slices: store.data.slices)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Verdict

    /// How even the split is, said out loud. A ring shows the shape; this says
    /// what the shape means, which is the part a household will actually argue
    /// about.
    @ViewBuilder
    private var verdictCard: some View {
        if let verdict = store.verdict {
            GlassCard(tint: verdict.tint.opacity(0.12)) {
                HStack(spacing: 14) {
                    Image(systemName: verdict.symbol)
                        .font(.title2)
                        .foregroundStyle(verdict.tint)
                        .frame(width: 34)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(verdict.title).font(.headline)
                        Text(verdict.message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Leaderboard

    private var leaderboard: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(L10n.contributionsLeaderboardTitle, symbol: "trophy.fill")

            GlassList {
                ForEach(Array(store.data.ranked.enumerated()), id: \.element.id) { rank, member in
                    MemberRow(
                        member: member,
                        rank: rank,
                        share: store.data.share(of: member),
                        isMe: member.userID == store.currentUserID
                    )
                }
            }
        }
    }

    // MARK: - Activity

    private var activity: some View {
        VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
            SectionHeader(
                L10n.contributionsActivityTitle,
                subtitle: L10n.contributionsActivitySubtitle,
                symbol: "waveform.path.ecg"
            )

            GlassCard {
                ActivityChart(days: store.data.days, busiest: store.data.busiestDay)
            }
        }
    }
}

// MARK: - Row

/// One person's line on the leaderboard.
private struct MemberRow: View {
    let member: MemberContribution
    let rank: Int
    let share: Double
    let isMe: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Avatar(initials: member.initials, seed: member.userID.rawValue, size: 40)
                // Only the podium is marked; a badge on everyone is just noise,
                // and fifth place does not need a rosette. An SF Symbol rather
                // than a 🥇: the medal emoji has no glyph in every environment
                // the app renders in, and a tofu box next to someone's face is
                // worse than no medal at all.
                if rank < 3, member.completed > 0 {
                    Circle()
                        .fill(Self.podium[rank])
                        .frame(width: 18, height: 18)
                        .overlay {
                            // The leaderboard reorders as work lands, so this
                            // is a number that moves rather than a label.
                            Text(rank + 1, format: .number)
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText(value: Double(rank + 1)))
                                .animation(Motion.spring, value: rank)
                        }
                        .overlay(Circle().strokeBorder(.background, lineWidth: 1.5))
                        .offset(x: 3, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(isMe ? String(localized: L10n.contributionsYou) : member.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if member.streak > 1 {
                        Badge(
                            String(localized: L10n.contributionsStreak(member.streak)),
                            tint: Palette.warning,
                            symbol: "flame.fill"
                        )
                    }
                    Spacer(minLength: 0)
                    Text(share, format: .percent.precision(.fractionLength(0)))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: share))
                }

                ShareBar(
                    slices: [ContributionSlice(
                        id: member.userID.rawValue,
                        value: share,
                        seed: member.userID.rawValue,
                        label: member.displayName
                    )],
                    height: 6
                )

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(member.overdue > 0 ? Palette.danger : .secondary)
                    .lineLimit(1)
            }
        }
        .glassRow()
        .accessibilityElement(children: .combine)
    }

    /// Gold, silver, bronze.
    private static let podium: [Color] = [Palette.amber, Palette.silver, Palette.bronze]

    /// "12 done · 3 open · 1 overdue", trimmed to what is actually true — a row
    /// that always shows three clauses reads as a form, and two of them are
    /// usually zero.
    private var subtitle: String {
        var parts = [String(localized: L10n.contributionsDoneCount(member.completed))]
        if member.openAssigned > 0 {
            parts.append(String(localized: L10n.contributionsOpenCount(member.openAssigned)))
        }
        if member.overdue > 0 {
            parts.append(String(localized: L10n.contributionsOverdueCount(member.overdue)))
        }
        if let top = member.byKind.first, member.completed > 0 {
            parts.append(String(localized: top.kind.title))
        }
        return parts.joined(separator: " · ")
    }
}
