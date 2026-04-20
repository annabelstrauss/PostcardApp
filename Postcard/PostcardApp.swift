//
//  PostcardApp.swift
//  Postcard
//
//  Created by Annabel Strauss on 2/2/25.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

@main
struct PostcardApp: App {
    init() {
        FirebaseApp.configure()
        Task {
            do {
                try await Auth.auth().signInAnonymously()
            } catch {
                print("❌ Anonymous auth failed: \(error)")
            }
        }
    }
    
    // Initialize Firebase
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
