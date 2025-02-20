import Foundation

enum SendblueError: Error {
    case invalidResponse
    case apiError(String, Int)
    case networkError(Error)
    case invalidPhoneNumber
    case invalidConfiguration
}

class SendblueManager {
    static let shared = SendblueManager()
    
    private let apiKey = Config.value(for: "SENDBLUE_API_KEY")
    private let apiSecret = Config.value(for: "SENDBLUE_API_SECRET")
    private let baseURL = "https://api.sendblue.co/api"
    
    private init() {
        // Validate credentials exist
        guard !apiKey.isEmpty, !apiSecret.isEmpty else {
            fatalError("Sendblue API credentials not configured. Please add them to Config.plist")
        }
    }
    
    func sendInitialMessage(to phoneNumber: String) async throws {
        // Format phone number to E.164 format
        let formattedPhone = SendblueManager.formatPhoneNumber(phoneNumber)
        
        let message = "Hi! Annabel Strauss is trying to send you a postcard 💌 What address should we send it to?"
        
        let endpoint = "\(baseURL)/send-message"
        let parameters: [String: Any] = [
            "from_number": "+14152005823",
            "number": formattedPhone,
            "content": message
        ]
        
        print("📤 Sending request to Sendblue...")
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "SB-API-KEY-ID")
        request.setValue(apiSecret, forHTTPHeaderField: "SB-API-SECRET-KEY")
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SendblueError.invalidResponse
            }
            
            // Print response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Sendblue Response (Status \(httpResponse.statusCode)):")
                print(responseString)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw SendblueError.apiError("Failed to send initial message", httpResponse.statusCode)
            }
        } catch {
            throw SendblueError.networkError(error)
        }
    }
    
    public static func formatPhoneNumber(_ phone: String) -> String {
        // Remove any non-numeric characters
        let numbers = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // If it starts with 1 and has 11 digits, add +, otherwise add +1
        if numbers.hasPrefix("1") && numbers.count == 11 {
            return "+" + numbers
        } else {
            return "+1" + numbers
        }
    }
} 
