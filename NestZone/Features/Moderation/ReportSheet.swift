import ComposableArchitecture
import SwiftUI

/// Why somebody is reporting this, and a place to say more.
struct ReportSheet: View {
    @Bindable var store: StoreOf<ReportFeature>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let noteLimit = 500

    var body: some View {
        NavigationStack {
            Form {
                if let preview = store.preview, !preview.isEmpty {
                    Section {
                        Text(preview)
                            .font(.subheadline)
                            .foregroundStyle(.secondaryText)
                            .lineLimit(4)
                    } header: {
                        Text(L10n.reportSubjectHeader)
                    }
                }

                Section {
                    ForEach(ReportReason.allCases) { reason in
                        Button { store.send(.reasonSelected(reason)) } label: {
                            HStack {
                                Text(reason.title).foregroundStyle(.primary)
                                Spacer(minLength: 0)
                                if store.reason == reason {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.accentText)
                                        .transition(AnyTransition.scale.combined(with: .opacity).reduced(reduceMotion))
                                }
                            }
                            .contentShape(.rect)
                        }
                        .accessibilityAddTraits(store.reason == reason ? .isSelected : [])
                    }
                } header: {
                    Text(L10n.reportReasonHeader)
                }

                Section {
                    TextField(text: $store.note, axis: .vertical) {
                        Text(L10n.reportNotePlaceholder)
                    }
                    .lineLimit(2...5)
                    .onChange(of: store.note) { _, note in
                        if note.count > Self.noteLimit {
                            store.note = String(note.prefix(Self.noteLimit))
                        }
                    }
                } header: {
                    Text(L10n.reportNoteHeader)
                } footer: {
                    Text(L10n.reportFooter)
                }

                if let error = store.error {
                    Section {
                        Label { Text(error) } icon: {
                            Image(systemName: "exclamationmark.circle.fill")
                        }
                        .foregroundStyle(Palette.danger)
                    }
                }
            }
            .animation(Motion.spring, value: store.reason)
            .sensoryFeedback(.selection, trigger: store.reason)
            .navigationTitle(Text(L10n.reportTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() } label: { Text(L10n.commonCancel) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { store.send(.submitTapped) } label: {
                        if store.isSubmitting {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(L10n.reportSend).bold()
                        }
                    }
                    .disabled(!store.canSubmit)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

extension ReportReason {
    var title: LocalizedStringResource {
        switch self {
        case .abuse: L10n.reportReasonAbuse
        case .harassment: L10n.reportReasonHarassment
        case .sexual: L10n.reportReasonSexual
        case .spam: L10n.reportReasonSpam
        case .other: L10n.reportReasonOther
        }
    }
}

/// The thanks, or the daily-limit note, as one glass capsule over whatever
/// is behind it. Floats, so it is glass.
struct ReportNoticeToast: View {
    let notice: ReportNotice

    var body: some View {
        Label {
            Text(notice.copy)
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.leading)
        } icon: {
            Image(systemName: notice.symbol)
                .symbolRenderingMode(.hierarchical)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, Metrics.screenPadding)
        .accessibilityElement(children: .combine)
    }
}

/// A report sheet for a screen that has no store of its own (the avatar
/// viewer is plain SwiftUI): builds one and hands the answer back.
struct ReportSheetHost: View {
    @State private var store: StoreOf<ReportFeature>

    init(
        subject: ReportSubject,
        preview: String? = nil,
        onReported: @escaping (ReportOutcome) -> Void
    ) {
        _store = State(initialValue: Store(
            initialState: ReportFeature.State(subject: subject, preview: preview)
        ) {
            ReportFeature()
            // Nothing above this view is listening to the sheet's delegate.
            Reduce { _, action in
                if case let .delegate(.reported(outcome)) = action { onReported(outcome) }
                return .none
            }
        })
    }

    var body: some View {
        ReportSheet(store: store)
    }
}
