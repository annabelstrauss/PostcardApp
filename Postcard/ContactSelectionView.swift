import SwiftUI
import Contacts

struct ContactSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRecipient: Recipient?
    @State private var searchText = ""
    @State private var contacts: [CNContact] = []
    @State private var isShowingPermissionAlert = false
    
    var filteredContacts: [CNContact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { contact in
            let fullName = "\(contact.givenName) \(contact.familyName)"
            return fullName.lowercased().contains(searchText.lowercased())
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // How this works section
                VStack(alignment: .leading, spacing: 16) {
                    Text("how this works")
                        .font(.system(size: 17, weight: .semibold))
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Add your explanation text here
                    Text("Select a friend from your contacts to send them a physical postcard.")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
                .frame(maxWidth: .infinity)
                .background(Color(red: 246/255, green: 245/255, blue: 243/255))
                
                // Search bar
                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                // Contacts list
                List(filteredContacts, id: \.identifier) { contact in
                    ForEach(contact.phoneNumbers, id: \.identifier) { phoneNumber in
                        Button(action: {
                            // Create Recipient with name and phone
                            selectedRecipient = Recipient(
                                name: "\(contact.givenName) \(contact.familyName)",
                                phone: phoneNumber.value.stringValue
                            )
                            dismiss()
                        }) {
                            HStack {
                                // Contact avatar circle
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                VStack(alignment: .leading) {
                                    // Contact name
                                    Text("\(contact.givenName) \(contact.familyName)")
                                        .foregroundColor(.black)
                                    
                                    // Phone number
                                    Text(phoneNumber.value.stringValue)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
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
            requestContactsAccess()
        }
        .alert("Contacts Access Required", isPresented: $isShowingPermissionAlert) {
            Button("Open Settings", role: .none) {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow access to your contacts to select a recipient for your postcard.")
        }
    }
    
    private func requestContactsAccess() {
        Task {  // Wrap in Task to move off main thread
            let store = CNContactStore()
            do {
                let granted = try await store.requestAccess(for: .contacts)
                if granted {
                    await loadContacts()
                } else {
                    await MainActor.run {
                        isShowingPermissionAlert = true
                    }
                }
            } catch {
                print("Error requesting contacts access: \(error)")
            }
        }
    }
    
    private func loadContacts() async {
        let store = CNContactStore()
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey]
        let request = CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor])
        
        do {
            var allContacts: [CNContact] = []
            try await Task.detached {
                try store.enumerateContacts(with: request) { contact, stop in
                    if !contact.phoneNumbers.isEmpty {
                        allContacts.append(contact)
                    }
                }
            }.value
            
            await MainActor.run {
                self.contacts = allContacts.sorted {
                    $0.givenName.lowercased() < $1.givenName.lowercased()
                }
            }
        } catch {
            print("Error fetching contacts: \(error)")
        }
    }
} 