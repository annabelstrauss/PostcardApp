//
//  ContentView.swift
//  Postcard
//
//  Created by Annabel Strauss on 2/2/25.
//

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct IgnoreKeyboardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .ignoresSafeArea(.keyboard)
            .onAppear {
                // Disable automatic keyboard adjustment
                UIScrollView.appearance().keyboardDismissMode = .none
            }
    }
}

struct ContentView: View {
    // MARK: - State Variables
    // For photo selection and display
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: Image?
    
    // Controls which side of postcard is showing (front/back)
    @State private var isShowingFront = true
    
    // For the message on back of postcard
    @State private var message = ""
    @FocusState private var isMessageFocused: Bool
    
    // Controls the photo picker sheet
    @State private var isShowingPhotoPicker = false
    
    // Add state for delete confirmation
    @State private var isShowingDeleteAlert = false

    // Add state for button animations
    @State private var isSendPressed = false
    @State private var isMailPressed = false
    @State private var isDeletePressed = false

    // Add states for haptic feedback
    @State private var mailHaptic = UIImpactFeedbackGenerator(style: .medium)
    @State private var deleteHaptic = UIImpactFeedbackGenerator(style: .medium)
    @State private var sendHaptic = UIImpactFeedbackGenerator(style: .medium)
    @State private var photoHaptic = UIImpactFeedbackGenerator(style: .medium)
    
    // Add this state variable at the top with other @State properties
    @State private var isShowingContactPicker = false
    @State private var selectedRecipient: Recipient?

    // Add these state variables at the top with other @State properties
    @State private var isShowingSentConfirmation = false
    @State private var isSaving = false

    // Add this state variable at the top with other @State properties
    @State private var isShowingSentPostcards = false

    // White to grey custom gradient definition
    private let customGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 255/255, green: 253/255, blue: 250/255), // #FFFDFA
            Color(red: 234/255, green: 235/255, blue: 235/255)  // #EAEBEB
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    // Add this computed property near the top of ContentView with other properties
    private var canSendPostcard: Bool {
        selectedImage != nil && !message.isEmpty && selectedRecipient != nil
    }

    // Add this computed property near the other computed properties
    private var hasPostcardData: Bool {
        selectedImage != nil || !message.isEmpty || selectedRecipient != nil
    }
    
    var body: some View {
        ZStack {
            // Main background color
            Color(red: 218/255, green: 217/255, blue: 209/255)
                .ignoresSafeArea()
            VStack {
                // MARK: - Top Action Buttons
                HStack {
                    // Already sent button
                    Text("💌")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                        .frame(width: 34, height: 34)
                        .background(customGradient)
                        .cornerRadius(1)
                        .shadow(color: .black.opacity(0.19), radius: 10, x: 1, y: 4)
                        .rotationEffect(.degrees(isMailPressed ? 8.4 : -8.4))
                        .onTapGesture {
                            mailHaptic.impactOccurred()
                            // Trigger the animation
                            withAnimation(.spring(duration: 0.3)) {
                                isMailPressed = true
                            }
                            // Show sent postcards sheet
                            isShowingSentPostcards = true
                            // Reset after a short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.spring(duration: 0.3)) {
                                    isMailPressed = false
                                }
                            }
                        }
                    
                    Spacer()
                    
                    // Delete button
                    Text("🗑️")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .frame(width: 34, height: 34)
                        .background(customGradient)
                        .cornerRadius(1)
                        .shadow(color: .black.opacity(0.19), radius: 10, x: 1, y: 4)
                        .rotationEffect(.degrees(isDeletePressed && !hasPostcardData ? -6.0 : 6.0))
                        .onTapGesture {
                            deleteHaptic.impactOccurred()
                            // Only show delete alert if there's data to delete
                            if hasPostcardData {
                                isShowingDeleteAlert = true
                            }
                            // Trigger the animation only if there's no data
                            if !hasPostcardData {
                                withAnimation(.spring(duration: 0.3)) {
                                    isDeletePressed = true
                                }
                                // Reset after a short delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation(.spring(duration: 0.3)) {
                                        isDeletePressed = false
                                    }
                                }
                            }
                        }
                }
                .frame(width: 306)
                .padding(.top, 40) // !!!
                .padding(.bottom, 40) // !!!
                
                // Spacer() THIS
                
                // MARK: - Postcard View
                ZStack {
                    if isShowingFront {
                        // Front of postcard
                        ZStack {
                            // Background color
                            Rectangle()
                                .fill(Color(red: 246/255, green: 245/255, blue: 243/255))
                                .frame(width: 306, height: 424)
                            
                            // Add centered text when no photo is selected
                            if selectedImage == nil {
                                Text("send a postcard to a friend 💌")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 12))
                                    .fontWeight(.semibold)
                            }
                            
                            // Selected photo if one exists
                            if let selectedImage {
                                selectedImage
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 306, height: 424)
                                    .clipShape(Rectangle())
                            }
                            
                            // White inner border
                            Rectangle()
                                .stroke(Color.white, lineWidth: 9)
                                .frame(width: 306, height: 424)
                        }
                        // Tap to select/change photo
                        .onTapGesture {
                            photoHaptic.impactOccurred()
                            isShowingPhotoPicker = true
                        }
                        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedItem)
                    } else {
                        // Back of postcard
                        ZStack {
                            // Add gradient background
                            Rectangle()
                                .fill(customGradient)
                                .frame(width: 306, height: 424)
                            
                            TextEditor(text: $message)
                                .frame(width: 282, height: 424) //width controls text field width
                                .scrollContentBackground(.hidden)
                                .background(
                                    Text("Greetings from...")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .opacity(message.isEmpty ? 1 : 0)
                                        .allowsHitTesting(false)
                                        .padding(.top, 9)
                                        .padding(.leading, 5)
                                    , alignment: .topLeading
                                )
                                .padding(.top, 24) //controls cursor position from top of postcard
                                .cornerRadius(2)
                                .focused($isMessageFocused)
                                // Counter-rotate the text so it's not mirrored
                                .rotation3DEffect(
                                    .degrees(180),
                                    axis: (x: 0.0, y: 1.0, z: 0.0)
                                )
                        }
                        // Show keyboard when flipped to back
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isMessageFocused = true
                            }
                        }
                    }
                }
                // MARK: - Postcard Flip Animation
                .rotation3DEffect(
                    .degrees(isShowingFront ? 0 : -180),
                    axis: (x: 0.0, y: 1.0, z: 0.0)
                )
                // Horizontal swipe gesture to flip postcard
                .gesture(
                    DragGesture()
                        .onEnded { gesture in
                            let threshold: CGFloat = 50  // Minimum swipe distance
                            if abs(gesture.translation.width) > threshold {
                                if selectedImage != nil || !isShowingFront {
                                    withAnimation(.easeInOut(duration: 0.6)) {
                                        isShowingFront.toggle()
                                        if !isShowingFront {
                                            isMessageFocused = true
                                        }
                                    }
                                }
                            }
                        }
                )
                .shadow(color: .black.opacity(0.25), radius: 20) // Postcard shadow
                
                // Reduce this spacer height to move bottom controls up
                Spacer()
                    .frame(height: 20) // Adjust this value to control spacing
                
                // MARK: - Bottom Controls
                VStack(spacing: 16) {
                    // Recipient input field
                    HStack {
                        Text("Send to")
                            .fontWeight(.semibold)
                            .foregroundColor(Color(red: 168/255, green: 167/255, blue: 159/255))
                        Spacer()
                        if let recipient = selectedRecipient {
                            Text(recipient.name)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(red: 81/255, green: 80/255, blue: 76/255))
                        } else {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color(red: 81/255, green: 80/255, blue: 76/255))
                        }
                    }
                    .frame(width: 306)
                    .padding(.top, 10)
                    .onTapGesture {
                        isShowingContactPicker = true
                    }
                    // Price display
                    HStack {
                        Text("Total")
                            .fontWeight(.semibold)
                            .foregroundColor(Color(red: 168/255, green: 167/255, blue: 159/255))
                        Spacer() // this one's ok bc horizontal
                        Text("Free")
                            .fontWeight(.semibold)
                            .foregroundColor(Color(red: 81/255, green: 80/255, blue: 76/255))
                    }
                    .frame(width: 306) // Same width as postcard
                    .padding(.top, 10) // Adjust this value to match your desired vertical spacing
                    
                    // Send button
                    Button(action: {
                        sendHaptic.impactOccurred()
                        if canSendPostcard {
                            sendPostcard()
                        }
                        // Trigger the animation
                        withAnimation(.spring(duration: 0.3)) {
                            isSendPressed = true
                        }
                        // Reset after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring(duration: 0.3)) {
                                isSendPressed = false
                            }
                        }
                    }) {
                        Text("SEND")
                            .fontWeight(.bold)
                            .foregroundColor(canSendPostcard ? 
                                Color(red: 47/255, green: 16/255, blue: 241/255) : // #2F10F1
                                Color.gray)
                            .frame(width: 86, height: 38)
                            .background(customGradient)
                            .cornerRadius(1)
                            .shadow(color: .black.opacity(0.19), radius: 10, x: 1, y: 4)
                            .rotationEffect(.degrees(isSendPressed ? -7.0 : 3.5))
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
        .modifier(IgnoreKeyboardModifier())
        // Replace confirmation dialog with alert
        .alert("Start over?", isPresented: $isShowingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Yes", role: .destructive) {
                // Clear the postcard
                selectedImage = nil
                selectedItem = nil
                message = ""
                selectedRecipient = nil
                // Ensure we're showing the front after deletion
                if !isShowingFront {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        isShowingFront = true
                    }
                }
            }
        }

        // MARK: - Photo Loading Handler
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = Image(uiImage: uiImage)
                }
            }
        }

        // Add this sheet presentation modifier after the other modifiers (like .alert)
        .sheet(isPresented: $isShowingContactPicker) {
            ContactSelectionView(selectedRecipient: $selectedRecipient)
        }

        // Add this alert after the other modifiers
        .alert("We're on it!", isPresented: $isShowingSentConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your postcard is being sent")
        }

        // Add loading indicator if needed
        .overlay {
            if isSaving {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
            }
        }

        // Add this sheet presentation modifier near the other sheet modifiers
        .sheet(isPresented: $isShowingSentPostcards) {
            SentPostcardsView()
        }
    }

    // Add this function to handle saving and sending the postcard
    private func sendPostcard() {
        guard canSendPostcard,
              let selectedImage = selectedImage,
              let uiImage = selectedImage.asUIImage(),
              let imageData = uiImage.jpegData(compressionQuality: 0.8),
              let recipient = selectedRecipient else {
            print("❌ Failed guard check in sendPostcard()")
            return
        }
        
        isSaving = true
        
        let postcard = PostcardModel(
            id: nil,
            imageData: imageData,
            message: message,
            recipientName: recipient.name,
            recipientPhone: recipient.phone,
            dateCreated: Date(),
            address: nil,
            status: .pending
        )

        // Debug prints
        print("📬 Starting postcard send process:")
        print("To: \(postcard.recipientName)")
        print("Phone: \(postcard.recipientPhone)")
        print("Message length: \(postcard.message.count) characters")
        print("Image size: \(imageData.count / 1024) KB")

        Task {
            do {
                print("💾 Saving to Firebase...")
                let savedPostcard = try await FirebaseManager.shared.savePostcard(postcard)
                print("✅ Firebase save successful, id: \(savedPostcard.id ?? "nil")")
                
                print("📱 Sending initial message...")
                try await SendblueManager.shared.sendInitialMessage(to: recipient.phone)
                print("✅ Initial message sent successfully")
                
                print("📝 Updating postcard status...")
                try await FirebaseManager.shared.updatePostcardStatus(id: savedPostcard.id!, status: .addressRequested)
                print("✅ Status updated successfully")

                await MainActor.run {
                    isShowingSentConfirmation = true
                    isSaving = false
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        resetForm()
                    }
                }
            } catch {
                print("❌ Error in send process: \(error)")
                if let nsError = error as NSError? {
                    print("Domain: \(nsError.domain)")
                    print("Code: \(nsError.code)")
                    print("Description: \(nsError.localizedDescription)")
                    print("User Info: \(nsError.userInfo)")
                }
                
                await MainActor.run {
                    isSaving = false
                    // TODO: Show error alert to user
                }
            }
        }
    }

    // Add this helper function to reset the form
    private func resetForm() {
        selectedImage = nil
        selectedItem = nil
        message = ""
        selectedRecipient = nil
        if !isShowingFront {
            withAnimation(.easeInOut(duration: 0.6)) {
                isShowingFront = true
            }
        }
    }
}

#Preview {
    ContentView()
}
