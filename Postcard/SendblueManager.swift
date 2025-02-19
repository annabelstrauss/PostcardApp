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
        
        let message = "Hi! Annabel Strauss is trying to send you a postcard 💌 What is your address?"
        
        let endpoint = "\(baseURL)/send-message"
        let parameters: [String: Any] = [
            "from_number": "+14152005823", //The message dispatcher
            "number": formattedPhone,
            "content": message
        ]
        
        print("📤 Sending request to Sendblue:")
        print("Endpoint: \(endpoint)")
        print("Phone: \(formattedPhone)")
        
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
            
            // Check for specific status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success
                return
            case 400:
                throw SendblueError.apiError("Bad request - check phone number format", 400)
            case 401:
                throw SendblueError.apiError("Authentication failed - check API credentials", 401)
            case 403:
                throw SendblueError.apiError("Forbidden - account may be inactive", 403)
            case 429:
                throw SendblueError.apiError("Rate limit exceeded", 429)
            default:
                throw SendblueError.apiError("Server error: \(httpResponse.statusCode)", httpResponse.statusCode)
            }
        } catch let error as SendblueError {
            throw error
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
    
    func sendThankYouMessage(to phoneNumber: String) async throws {
        let message = "Thank you."
        
        let endpoint = "\(baseURL)/send-message"
        let parameters: [String: Any] = [
            "phone_number": phoneNumber,
            "message": message,
            "service": "imessage"
        ]
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "SB-API-KEY-ID")
        request.setValue(apiSecret, forHTTPHeaderField: "SB-API-SECRET-KEY")
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SendblueError.invalidResponse
        }
        
        // Handle response if needed
        print("Thank you message sent successfully: \(String(data: data, encoding: .utf8) ?? "")")
    }
} 
