import SwiftUI
import FirebaseFirestore

// MARK: - PostcardRow Component
struct PostcardRow: View {
    let postcard: PostcardModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Postcard image
            if let imageUrl = postcard.imageUrl,
               let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 69, height: 95)
                        .clipShape(Rectangle())
                        .overlay(
                            Rectangle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 10)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 69, height: 95)
                        .overlay(
                            Rectangle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 10)
                }
            }
            
            // Recipient and date
            VStack(alignment: .leading, spacing: 4) {
                Text("To: \(postcard.recipientName)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)
                
                Text(postcard.dateCreated.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.black)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

// MARK: - Main View
struct SentPostcardsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var postcards: [PostcardModel] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color(red: 246/255, green: 245/255, blue: 243/255)
                    .ignoresSafeArea()
                
                Group {
                    if isLoading {
                        ProgressView()
                    } else if postcards.isEmpty {
                        ContentUnavailableView(
                            "No Postcards Yet",
                            systemImage: "envelope",
                            description: Text("Postcards you send will appear here")
                        )
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                ForEach(postcards, id: \.id) { postcard in
                                    PostcardRow(postcard: postcard)
                                }
                            }
                            .padding(.vertical, 16)
                        }
                    }
                }
            }
            .navigationTitle("Sent Postcards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .onAppear {
            loadPostcards()
        }
    }
    
    private func loadPostcards() {
        Task {
            do {
                postcards = try await FirebaseManager.shared.fetchSentPostcards()
                isLoading = false
            } catch {
                print("Error loading postcards: \(error)")
                isLoading = false
            }
        }
    }
} 