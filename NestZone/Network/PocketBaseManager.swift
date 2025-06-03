import Foundation
import Alamofire

@MainActor
class PocketBaseManager {
    static let shared = PocketBaseManager()
    
    private let baseURL = "https://nestzone.walhallaa.com"
    private var authToken: String?
    
    private init() {}
    
    enum PocketBaseError: LocalizedError {
        case networkError
        case invalidResponse
        case unauthorized
        case forbidden
        case notFound
        case badRequest
        case serverError(String)
        
        var errorDescription: String? {
            switch self {
            case .networkError: return "Network error occurred"
            case .invalidResponse: return "Invalid server response"
            case .unauthorized: return "Invalid authorization token"
            case .forbidden: return "Not allowed to perform this action"
            case .notFound: return "Resource not found"
            case .badRequest: return "Bad request"
            case .serverError(let message): return message
            }
        }
    }
    
    // MARK: - Auth Token Management
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }
    
    func getAuthToken() -> String? {
        return authToken
    }
    
    // MARK: - Generic Request Methods
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        requiresAuth: Bool = false,
        responseType: T.Type
    ) async throws -> T {
        var headers: HTTPHeaders = [
            "Content-Type": "application/json"
        ]
        
        if requiresAuth, let token = authToken {
            headers["Authorization"] = token
        }
        
        let response = await AF.request(
            "\(baseURL)\(endpoint)",
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers
        )
        .validate()
        .serializingDecodable(T.self)
        .response
        
        switch response.result {
        case .success(let data):
            return data
        case .failure:
            throw mapError(from: response)
        }
    }
    
    func requestWithoutResponse(
        endpoint: String,
        method: HTTPMethod = .post,
        parameters: [String: Any]? = nil,
        requiresAuth: Bool = false
    ) async throws {
        var headers: HTTPHeaders = [
            "Content-Type": "application/json"
        ]
        
        if requiresAuth, let token = authToken {
            headers["Authorization"] = token
        }
        
        let response = await AF.request(
            "\(baseURL)\(endpoint)",
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers
        )
        .validate()
        .serializingData()
        .response
        
        if case .failure = response.result {
            throw mapErrorFromDataResponse(response)
        }
    }
    
    // MARK: - Collection Helpers
    func getCollection<T: Codable>(
        _ collection: String,
        responseType: T.Type,
        filter: String? = nil,
        sort: String? = nil
    ) async throws -> T {
        var endpoint = "/api/collections/\(collection)/records"
        var queryItems: [String] = []
        
        if let filter = filter {
            queryItems.append("filter=\(filter)")
        }
        if let sort = sort {
            queryItems.append("sort=\(sort)")
        }
        
        if !queryItems.isEmpty {
            endpoint += "?" + queryItems.joined(separator: "&")
        }
        
        return try await request(
            endpoint: endpoint,
            requiresAuth: true,
            responseType: responseType
        )
    }
    
    func createRecord<T: Codable>(
        in collection: String,
        data: [String: Any],
        responseType: T.Type
    ) async throws -> T {
        return try await request(
            endpoint: "/api/collections/\(collection)/records",
            method: .post,
            parameters: data,
            requiresAuth: true,
            responseType: responseType
        )
    }
    
    func updateRecord<T: Codable>(
        in collection: String,
        id: String,
        data: [String: Any],
        responseType: T.Type
    ) async throws -> T {
        return try await request(
            endpoint: "/api/collections/\(collection)/records/\(id)",
            method: .patch,
            parameters: data,
            requiresAuth: true,
            responseType: responseType
        )
    }
    
    func deleteRecord(from collection: String, id: String) async throws {
        try await requestWithoutResponse(
            endpoint: "/api/collections/\(collection)/records/\(id)",
            method: .delete,
            requiresAuth: true
        )
    }
    
    // MARK: - Error Mapping
    private func mapError<T>(from response: AFDataResponse<T>) -> PocketBaseError {
        guard let statusCode = response.response?.statusCode else {
            return .networkError
        }
        
        switch statusCode {
        case 400:
            if response.request?.url?.absoluteString.contains("/auth-with-password") == true {
                return .serverError("Invalid Credentials")
            } else {
                return .badRequest
            }
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        default:
            if let data = response.data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                return .serverError(message)
            } else {
                return .serverError("Server error: \(statusCode)")
            }
        }
    }
    
    private func mapErrorFromDataResponse(_ response: AFDataResponse<Data>) -> PocketBaseError {
        guard let statusCode = response.response?.statusCode else {
            return .networkError
        }
        
        switch statusCode {
        case 400:
            return .badRequest
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        default:
            if let data = response.data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                return .serverError(message)
            } else {
                return .serverError("Server error: \(statusCode)")
            }
        }
    }
}
