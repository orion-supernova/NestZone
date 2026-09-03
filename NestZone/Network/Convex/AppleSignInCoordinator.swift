//
//  AppleSignInCoordinator.swift
//  NestZone
//
//  Wraps ASAuthorizationController's delegate callbacks in an async call.
//
//  This is the NATIVE Sign in with Apple flow: Apple hands us a signed identity
//  token directly, with no browser redirect and no OAuth callback URL. That
//  matters for this backend — the self-hosted deployment only proxies
//  /.well-known/* to the HTTP-actions origin, so the redirect-based OAuth routes
//  would not be reachable. The backend verifies the token in convex/lib/apple.ts.
//

import Foundation
import AuthenticationServices

@MainActor
final class AppleSignInCoordinator: NSObject {
    struct Credential {
        let identityToken: String
        /// Apple supplies the name ONLY on the very first authorization, so this is
        /// nil for every subsequent sign-in. The backend keeps the stored name.
        let displayName: String?
    }

    enum Failure: LocalizedError {
        case cancelled
        case missingIdentityToken
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .cancelled:            return nil   // user backed out; not worth an alert
            case .missingIdentityToken: return "Apple didn't return a sign-in token. Please try again."
            case .underlying(let e):    return e.localizedDescription
            }
        }
    }

    private var continuation: CheckedContinuation<Credential, Error>?

    func signIn() async throws -> Credential {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func finish(_ result: Result<Credential, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let identityToken = String(data: tokenData, encoding: .utf8)
        else {
            finish(.failure(Failure.missingIdentityToken))
            return
        }

        let name = credential.fullName.flatMap { components -> String? in
            let formatted = PersonNameComponentsFormatter.localizedString(
                from: components, style: .default
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            return formatted.isEmpty ? nil : formatted
        }

        finish(.success(Credential(identityToken: identityToken, displayName: name)))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            finish(.failure(Failure.cancelled))
        } else {
            finish(.failure(Failure.underlying(error)))
        }
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
            ?? ASPresentationAnchor()
    }
}
