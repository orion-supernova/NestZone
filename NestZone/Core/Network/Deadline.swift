import Foundation

/// A call that ran out of time.
struct DeadlineExpired: Error {}

/// Runs a call against a clock and gives up on it when the clock wins.
///
/// An unstructured race, not a task group, and that is the point. The SDK's
/// calls end in a Rust future that does not look at Swift's cancellation, so a
/// task group would cancel the loser and then *wait for it*, which is the hang
/// this exists to end. Here the caller is released the moment the deadline
/// passes, and the abandoned call is left to finish (or not) on its own.
enum Deadline {
    static func run<T: Sendable>(
        _ limit: Duration,
        cancelsWork: Bool = true,
        _ body: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let race = Race<T>(cancelsWork: cancelsWork)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
                race.arm(continuation)
                let work = Task {
                    do {
                        race.finish(.success(try await body()))
                    } catch {
                        race.finish(.failure(error))
                    }
                }
                let timer = Task {
                    do { try await Task.sleep(for: limit) } catch { return }
                    race.finish(.failure(DeadlineExpired()))
                }
                race.hold(work: work, timer: timer)
            }
        } onCancel: {
            race.finish(.failure(CancellationError()))
        }
    }

    /// One winner, and whoever loses is cancelled.
    private final class Race<T: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<T, any Error>?
        private var work: Task<Void, Never>?
        private var timer: Task<Void, Never>?
        private var result: Result<T, any Error>?
        /// False for a call that must be allowed to finish once it is sent (a
        /// refresh-token exchange: the server rotates the token when it
        /// answers, and the answer has to be written down).
        private let cancelsWork: Bool

        init(cancelsWork: Bool) { self.cancelsWork = cancelsWork }

        func arm(_ continuation: CheckedContinuation<T, any Error>) {
            let early = lock.withLock { () -> Result<T, any Error>? in
                if let result { return result }
                self.continuation = continuation
                return nil
            }
            if let early { continuation.resume(with: early) }
        }

        func hold(work: Task<Void, Never>, timer: Task<Void, Never>) {
            let settled = lock.withLock { () -> Bool in
                self.work = work
                self.timer = timer
                return result != nil
            }
            if settled { if cancelsWork { work.cancel() }; timer.cancel() }
        }

        func finish(_ outcome: Result<T, any Error>) {
            let (waiting, work, timer) = lock.withLock {
                () -> (CheckedContinuation<T, any Error>?, Task<Void, Never>?, Task<Void, Never>?) in
                guard result == nil else { return (nil, nil, nil) }
                result = outcome
                defer { continuation = nil }
                return (continuation, self.work, self.timer)
            }
            if cancelsWork { work?.cancel() }
            timer?.cancel()
            waiting?.resume(with: outcome)
        }
    }
}
