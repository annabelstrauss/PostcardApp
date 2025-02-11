import SwiftUI
import FirebaseFirestore

struct PostcardModel: Identifiable, Codable {
    @DocumentID var id: String?
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case imageData
        case message
        case recipientName
        case recipientPhone
        case dateCreated
        case status
    }
}

// Keep this if you need it for contact selection
struct Recipient {
    let name: String
    let phone: String
} 