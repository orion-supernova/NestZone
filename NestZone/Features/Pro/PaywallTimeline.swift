import SwiftUI

/// What a free trial does, day by day, on the paywall: nothing now, a way out
/// at any time, and the day it turns into the paid plan. Only what is true is
/// promised: no reminder is scheduled, so none is mentioned, and the way out
/// is the one the App Store gives (Settings, before the last day).
struct TrialTimeline: View {
    /// Days of free access, from the store's own offer.
    let days: Int
    /// "$19.99/year", already formatted.
    let billed: String

    @Environment(\.theme) private var theme

    private struct Step: Identifiable {
        let id: Int
        let symbol: String
        let title: LocalizedStringResource
        let text: LocalizedStringResource
    }

    private var steps: [Step] {
        [
            Step(id: 0, symbol: "lock.open.fill",
                 title: L10n.paywallTimelineTodayTitle, text: L10n.paywallTimelineTodayText),
            Step(id: 1, symbol: "hand.raised.fill",
                 title: L10n.paywallTimelineCancelTitle("\(days)"), text: L10n.paywallTimelineCancelText),
            Step(id: 2, symbol: "creditcard.fill",
                 title: L10n.paywallTimelineEndTitle("\(days)"), text: L10n.paywallTimelineEndText(billed)),
        ]
    }

    var body: some View {
        let steps = steps
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 0) {
                            Image(systemName: step.symbol)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(step.id == 2 ? theme.onAccent : theme.ink)
                                .frame(width: 32, height: 32)
                                .background(step.id == 2 ? AnyShapeStyle(theme.accentFill) : AnyShapeStyle(theme.accent.opacity(0.16)), in: .circle)
                            if step.id != steps.count - 1 {
                                Rectangle()
                                    .fill(Palette.inset)
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title).font(.subheadline.weight(.semibold))
                            Text(step.text).font(.footnote).foregroundStyle(.secondaryText)
                        }
                        .padding(.bottom, step.id == steps.count - 1 ? 0 : 16)
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
