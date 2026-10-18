import ComposableArchitecture
import Foundation
import FoundationModels

/// A second opinion on which chip a line belongs under, from the on-device
/// model.
///
/// Asked only when the rules in `CaptureParser` are unsure, and only ever for
/// the *kind*. Guided generation is pinned to a six-case enum, so the model has
/// no field to put a title, a date, an amount or a name in — which is the
/// point: asked for the whole draft in testing, it named a payer nobody had
/// typed. Everything the sheet writes still comes from the rules.
///
/// Apple Intelligence is not on every phone, not switched on on every phone
/// that has it, and not in every language. `isAvailable` answers all three at
/// once, and when it says no the sheet simply works on rules alone — nothing on
/// screen says a model was ever involved.
@DependencyClient
public struct CaptureClassifierClient: Sendable {
    /// Whether the model is ready on this device, for this language. Cheap and
    /// synchronous, so it can be asked on every keystroke.
    public var isAvailable: @Sendable (Locale) -> Bool = { _ in false }
    /// Loads the model before the first question, so the first answer is not
    /// also the slow one. Called when the sheet opens.
    public var prewarm: @Sendable (Locale) async -> Void
    /// The kind `text` most likely is, or `nil` when the model would not say.
    public var classify: @Sendable (String, Locale) async throws -> CaptureKind?
}

extension CaptureClassifierClient: DependencyKey {
    public static let liveValue: CaptureClassifierClient = {
        let model = CaptureModel()
        return CaptureClassifierClient(
            isAvailable: { locale in CaptureModel.isAvailable(for: locale) },
            prewarm: { locale in await model.prewarm(locale) },
            classify: { text, locale in try await model.classify(text, locale: locale) }
        )
    }()

    /// No model, ever: tests and previews run on rules alone, which is also
    /// what most phones do.
    public static let testValue = CaptureClassifierClient(
        isAvailable: { _ in false },
        prewarm: { _ in },
        classify: { _, _ in nil }
    )

    public static let previewValue = testValue
}

extension DependencyValues {
    public var captureClassifier: CaptureClassifierClient {
        get { self[CaptureClassifierClient.self] }
        set { self[CaptureClassifierClient.self] = newValue }
    }
}

// MARK: - The live model

/// Holds one warmed session between the sheet opening and the first question.
///
/// Every question after that gets a session of its own. A session keeps its
/// transcript, and a classifier that remembers it just called "milk" shopping
/// is a classifier nudged towards calling the next line shopping too; a verdict
/// should depend on the words in front of it and nothing else.
actor CaptureModel {
    private var warmed: LanguageModelSession?

    /// Short on purpose: the model is small, and every sentence here is a
    /// sentence it reads before every answer.
    static let instructions = """
        You sort one short line that someone in a shared home typed into a \
        household app. The line may be in English or Turkish. Choose the one \
        place it belongs: shopping (things to buy), chore (a job to do around \
        the house), note (information to keep, such as a password or a code), \
        problem (something broken or wrong in the home that needs fixing), \
        event (a plan at a time, such as a dinner, a party or a visit), or \
        expense (money somebody already paid or spent).
        """

    static func isAvailable(for locale: Locale) -> Bool {
        let model = SystemLanguageModel.default
        guard model.availability == .available else { return false }
        return model.supportsLocale(locale)
    }

    func prewarm(_ locale: Locale) {
        guard Self.isAvailable(for: locale), warmed == nil else { return }
        let session = LanguageModelSession(instructions: Self.instructions)
        session.prewarm()
        warmed = session
    }

    func classify(_ text: String, locale: Locale) async throws -> CaptureKind? {
        guard Self.isAvailable(for: locale) else { return nil }
        let session = warmed ?? LanguageModelSession(instructions: Self.instructions)
        warmed = nil

        let prompt: String = "Line: \(text)"
        let response = try await session.respond(
            to: prompt,
            generating: CaptureVerdict.self,
            includeSchemaInPrompt: true,
            // Greedy: the same line should land under the same chip every
            // time it is typed.
            options: GenerationOptions(samplingMode: .greedy)
        )
        return response.content.kind
    }
}

/// The only thing the model is allowed to produce.
@Generable(description: "Where the line belongs in the household app.")
enum CaptureVerdict: Sendable {
    case shopping, chore, note, problem, event, expense

    var kind: CaptureKind {
        switch self {
        case .shopping: .shopping
        case .chore: .chore
        case .note: .note
        case .problem: .problem
        case .event: .event
        case .expense: .expense
        }
    }
}
