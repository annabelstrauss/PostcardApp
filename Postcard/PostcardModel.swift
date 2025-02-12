import SwiftUI
import FirebaseFirestore
import Foundation

struct PostcardModel: Identifiable, Codable {
    @DocumentID var id: String?
    var imageData: Data?  // Optional now
    var imageUrl: String? // New field for Firebase storage URL
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
        case imageUrl
        case message
        case recipientName
        case recipientPhone
        case dateCreated
        case status
    }
    
    // Custom initializer for creating new postcards locally
    init(id: String? = nil, imageData: Data, message: String, recipientName: String, recipientPhone: String, dateCreated: Date, status: PostcardStatus) {
        self.id = id
        self.imageData = imageData
        self.imageUrl = nil
        self.message = message
        self.recipientName = recipientName
        self.recipientPhone = recipientPhone
        self.dateCreated = dateCreated
        self.status = status
    }
    
    // Custom decoder init to handle both local and Firebase data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        message = try container.decode(String.self, forKey: .message)
        recipientName = try container.decode(String.self, forKey: .recipientName)
        recipientPhone = try container.decode(String.self, forKey: .recipientPhone)
        dateCreated = try container.decode(Date.self, forKey: .dateCreated)
        status = try container.decode(PostcardStatus.self, forKey: .status)
    }
}

// Keep this if you need it for contact selection
struct Recipient {
    let name: String
    let phone: String
} 