import Foundation
import Alamofire

@MainActor
class PocketBaseAuthManager: ObservableObject {
    @Published var currentUser: AuthUser?
    @Published var authToken: String?
    
    private let pocketBase = PocketBaseManager.shared
    
    enum AuthError: LocalizedError {
        case invalidCredentials
        case networkError
        case unauthorized
        case serverError(String)
        case passwordMismatch
        case weakPassword
        case emailAlreadyExists
        
        var errorDescription: String? {
            switch self {
            case .invalidCredentials: return "Wrong email or password"
            case .networkError: return "Network error occurred"
            case .unauthorized: return "Invalid authorization token"
            case .serverError(let message): return message
            case .passwordMismatch: return "Passwords don't match"
            case .weakPassword: return "Password must be at least 8 characters"
            case .emailAlreadyExists: return "An account with this email already exists"
            }
        }
    }
    
    init() {
        loadPersistedAuth()
        if let token = authToken {
            pocketBase.setAuthToken(token)
        }
    }
    
    func login(email: String, password: String) async throws {
        let parameters = [
            "identity": email,
            "password": password
        ]
        
        do {
            let authResponse: AuthResponse = try await pocketBase.request(
                endpoint: "/api/collections/users/auth-with-password",
                method: .post,
                parameters: parameters,
                responseType: AuthResponse.self
            )
            
            self.currentUser = authResponse.record
            self.authToken = authResponse.token
            self.pocketBase.setAuthToken(authResponse.token)
            self.persistAuth()
            
        } catch let error as PocketBaseManager.PocketBaseError {
            switch error {
            case .badRequest:
                throw AuthError.invalidCredentials
            case .networkError:
                throw AuthError.networkError
            case .unauthorized:
                throw AuthError.unauthorized
            case .serverError(let message):
                throw AuthError.serverError(message)
            default:
                throw AuthError.networkError
            }
        } catch {
            throw AuthError.networkError
        }
    }
    
    func register(email: String, password: String, fullName: String) async throws {
        // Validate password strength
        guard password.count >= 8 else {
            throw AuthError.weakPassword
        }
        
        let parameters = [
            "email": email,
            "password": password,
            "passwordConfirm": password,
            "name": fullName
        ]
        
        do {
            // First create the user account (returns UserCreationResponse without email/token)
            let _: UserCreationResponse = try await pocketBase.request(
                endpoint: "/api/collections/users/records",
                method: .post,
                parameters: parameters,
                responseType: UserCreationResponse.self
            )
            
            // After successful registration, automatically log in to get the full auth response
            try await login(email: email, password: password)
            
        } catch let error as PocketBaseManager.PocketBaseError {
            switch error {
            case .badRequest:
                throw AuthError.emailAlreadyExists
            case .networkError:
                throw AuthError.networkError
            case .serverError(let message):
                if message.contains("email") || message.contains("already exists") {
                    throw AuthError.emailAlreadyExists
                } else {
                    throw AuthError.serverError(message)
                }
            default:
                throw AuthError.networkError
            }
        } catch {
            throw AuthError.networkError
        }
    }
    
    func refreshAuth() async throws {
        guard authToken != nil else {
            throw AuthError.unauthorized
        }
        
        do {
            let authResponse: AuthResponse = try await pocketBase.request(
                endpoint: "/api/collections/users/auth-refresh",
                method: .post,
                requiresAuth: true,
                responseType: AuthResponse.self
            )
            
            self.currentUser = authResponse.record
            self.authToken = authResponse.token
            self.pocketBase.setAuthToken(authResponse.token)
            self.persistAuth()
            
        } catch let error as PocketBaseManager.PocketBaseError {
            switch error {
            case .unauthorized:
                self.logout()
                throw AuthError.unauthorized
            case .networkError:
                throw AuthError.networkError
            case .serverError(let message):
                throw AuthError.serverError(message)
            default:
                throw AuthError.networkError
            }
        } catch {
            throw AuthError.networkError
        }
    }
    
    func logout() {
        currentUser = nil
        authToken = nil
        pocketBase.setAuthToken(nil)
        clearPersistedAuth()
    }
    
    private func persistAuth() {
        if let user = currentUser, let token = authToken {
            if let userData = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(userData, forKey: "currentUser")
            }
            UserDefaults.standard.set(token, forKey: "authToken")
        }
    }
    
    private func loadPersistedAuth() {
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(AuthUser.self, from: userData) {
            currentUser = user
        }
        authToken = UserDefaults.standard.string(forKey: "authToken")
    }
    
    private func clearPersistedAuth() {
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "authToken")
    }
}