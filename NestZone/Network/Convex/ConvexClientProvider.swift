//
//  ConvexClientProvider.swift
//  NestZone
//
//  The single shared Convex client for the whole app. Replaces PocketBaseManager.
//  Every screen/VM reads live data via `Convex.client.subscribe(...)` and writes via
//  `Convex.client.mutation(...)`. See Docs/Convex-Migration/iOS-Migration-Guide.md §2, §4.
//

import Foundation
import Combine
import ConvexMobile
import os

enum Convex {
    /// Deployment origin of the self-hosted backend (set in the deploy runbook).
    static let deploymentURL = "https://nestzone-convex-api.walhallaa.com"

    /// Diagnostic logger (filter in Console/`log` with category "Convex").
    static let log = Logger(subsystem: "com.walhallaa.NestZone", category: "Convex")

    private static var diagnosticsBag = Set<AnyCancellable>()

    /// Log websocket connection state so we can see if the realtime socket connects.
    static func startDiagnostics() {
        client.watchWebSocketState()
            .sink { state in log.log("WS state: \(String(describing: state), privacy: .public)") }
            .store(in: &diagnosticsBag)
    }

    /// Drives the @convex-dev/auth Apple provider (sign-in + token refresh).
    static let authProvider = ConvexAppleAuthProvider(deploymentUrl: deploymentURL)

    /// Single shared, auth-aware client. Its generic `T` is inferred as
    /// `ConvexAuthTokens` from the provider.
    static let client = ConvexClientWithAuth(
        deploymentUrl: deploymentURL,
        authProvider: authProvider
    )

    /// One-shot read: subscribe to a query and return its first value, then unsubscribe.
    /// Convex has no non-reactive query in the Swift SDK, so this adapts a subscription
    /// for `async`/`await` call sites (managers that "load once"). For live UI, subscribe
    /// directly and keep the `AnyCancellable`.
    static func once<T: Decodable>(
        _ name: String,
        args: [String: ConvexEncodable?]? = nil,
        as type: T.Type = T.self
    ) async throws -> T {
        var cancellable: AnyCancellable?
        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            cancellable = client
                .subscribe(to: name, with: args, yielding: T.self)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion, !resumed {
                            resumed = true
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        if !resumed {
                            resumed = true
                            continuation.resume(returning: value)
                            cancellable?.cancel()
                        }
                    }
                )
        }
    }
}
