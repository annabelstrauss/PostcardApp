import FirebaseCore
import FirebaseFirestore
import FirebaseStorage

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    let db = Firestore.firestore()
    let storage = Storage.storage().reference()
    
    private init() {
        // Remove FirebaseApp.configure() from here
    }
    
    func savePostcard(_ postcard: PostcardModel) async throws {
        do {
            // 1. First upload the image to Storage
            guard let imageData = postcard.imageData else {
                throw NSError(domain: "PostcardError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No image data provided"])
            }
            
            let imageRef = storage.child("postcards/\(UUID().uuidString).jpg")
            print("Attempting to upload to path: \(imageRef.fullPath)")
            
            _ = try await imageRef.putDataAsync(imageData)
            print("Image upload successful")
            
            let imageUrl = try await imageRef.downloadURL()
            print("Got download URL: \(imageUrl.absoluteString)")
            
            // 2. Create a Firestore-friendly version of the postcard
            let postcardData: [String: Any] = [
                "imageUrl": imageUrl.absoluteString,
                "message": postcard.message,
                "recipientName": postcard.recipientName,
                "recipientPhone": postcard.recipientPhone,
                "dateCreated": postcard.dateCreated,
                "status": postcard.status.rawValue
            ]
            
            // 3. Save to Firestore
            try await db.collection("postcards").addDocument(data: postcardData)
        } catch {
            print("Detailed error: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("Error domain: \(nsError.domain)")
                print("Error code: \(nsError.code)")
                print("Error userInfo: \(nsError.userInfo)")
            }
            throw error
        }
    }
    
    func fetchSentPostcards() async throws -> [PostcardModel] {
        let snapshot = try await db.collection("postcards")
            .order(by: "dateCreated", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document -> PostcardModel? in
            var postcard = try document.data(as: PostcardModel.self)
            postcard.id = document.documentID
            return postcard
        }
    }
} 