import Foundation

extension AsyncThrowingStream where Element: Sendable, Failure == any Error {
    /// Mirrors every payload into the avatar directory on the way past.
    ///
    /// Applied in the client rather than in a reducer on purpose. A `User`
    /// document reaches this app through exactly three reads — `users:me`,
    /// `homes:members` and `users:byIds` — and wrapping all three means there
    /// is no path by which one arrives and the directory misses it. Done in one
    /// reducer instead, every screen fed by the other two would quietly draw
    /// initials over people who have photos, and the bug would look like a
    /// caching problem rather than a missing line.
    ///
    /// It costs one task per subscription and nothing per payload: the
    /// directory drops an identical dictionary without notifying anybody, which
    /// matters because Convex re-publishes every live query in the app whenever
    /// the query set changes.
    func recordingAvatars(
        _ record: @escaping @Sendable (Element) -> Void
    ) -> AsyncThrowingStream<Element, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await value in self {
                        record(value)
                        continuation.yield(value)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // The subscription underneath is only cancelled by cancelling the
            // task that is reading it, so the wrapper has to pass termination
            // through or every screen would leave a live query behind it.
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
