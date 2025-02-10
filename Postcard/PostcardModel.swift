import SwiftUI

struct PostcardData: Codable {
    let imageData: Data
    let message: String
    let recipientName: String
    let recipientPhone: String
    let dateCreated: Date
    let status: PostcardStatus
    
    enum PostcardStatus: String, Codable {
        case pending
        case sent
        case failed
    }
}

struct Recipient {
    let name: String
    let phone: String
} 