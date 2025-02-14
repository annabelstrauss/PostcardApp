import Foundation

enum Config {
    private static let defaults: [String: Any] = [
        "SENDBLUE_API_KEY": "",
        "SENDBLUE_API_SECRET": ""
    ]
    
    static func value(for key: String) -> String {
        // First try to get from environment
        if let environmentValue = ProcessInfo.processInfo.environment[key] {
            return environmentValue
        }
        
        // Then try from config file
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let value = dict[key] as? String {
            return value
        }
        
        // Finally fall back to defaults
        return defaults[key] as? String ?? ""
    }
} 