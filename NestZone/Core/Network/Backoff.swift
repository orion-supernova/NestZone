import ComposableArchitecture
import Foundation

/// Keeps a long-lived read alive.
///
/// `ConvexConnection.subscribe` already re-opens a dropped read for the errors
/// worth retrying; what it finishes with is an error it will not retry (a
/// refused session, say, which may well be fine a minute later). A feature that
/// swallowed that with `catch: { _, _ in }` stayed deaf until the app was
/// relaunched. This asks again, after 2 s, then 4, up to a minute, and starts
/// from 2 s again once the read has delivered something.
enum Backoff {
    static func retrying(
        clock: any Clock<Duration>,
        _ body: @Sendable (_ delivered: @Sendable () -> Void) async throws -> Void
    ) async {
        let delivered = LockIsolated(false)
        var wait = 2
        while !Task.isCancelled {
            delivered.setValue(false)
            do {
                try await body { delivered.setValue(true) }
                // A read that ends quietly (a refused session ends it so)
                // is asked for again, like one that failed.
            } catch is CancellationError {
                return
            } catch {}
            if Task.isCancelled { return }
            if delivered.value { wait = 2 }
            guard (try? await clock.sleep(for: .seconds(wait))) != nil else { return }
            wait = min(wait * 2, 60)
        }
    }
}
