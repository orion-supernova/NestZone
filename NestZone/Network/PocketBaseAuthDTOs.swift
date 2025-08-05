import Foundation

struct AuthResponse: Codable {
    let token: String
    let record: AuthUser
}

struct AuthUser: Codable, Identifiable {
    let id: String
    let collectionId: String
    let collectionName: String
    let email: String
    let emailVisibility: Bool
    let verified: Bool
    let name: String
    let avatar: String?
    let created: String
    let updated: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case collectionId
        case collectionName
        case email
        case emailVisibility
        case verified
        case name
        case avatar
        case created
        case updated
    }
}

struct UserCreationResponse: Codable {
    let id: String
    let collectionId: String
    let collectionName: String
    let emailVisibility: Bool
    let verified: Bool
    let name: String
    let avatar: String?
    let home_id: [String]
    let created: String
    let updated: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case collectionId
        case collectionName
        case emailVisibility
        case verified
        case name
        case avatar
        case home_id
        case created
        case updated
    }
}