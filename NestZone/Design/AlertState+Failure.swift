import ComposableArchitecture

extension AlertState {
    /// The app's one error alert.
    ///
    /// Screens used to build these individually and show
    /// `error.localizedDescription` straight from Convex, which put strings like
    /// "The data couldn't be read because it isn't in the correct format" in
    /// front of users. `AppError` maps to copy a person can act on.
    public static func failure(_ error: AppError) -> AlertState {
        AlertState {
            TextState(String(localized: L10n.commonErrorTitle))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonOkButton))
            }
        } message: {
            TextState(error.errorDescription ?? "")
        }
    }
}
