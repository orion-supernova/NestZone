import SwiftUI

struct NewMessageView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @State private var selectedContacts: [String] = []
    @State private var messageText = ""
    @State private var isGroupChat = false
    @State private var groupTitle = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let householdMembers: [PocketBaseUser]
    let currentHomeId: String
    var onMessageSent: ((PocketBaseConversation) -> Void)? = nil
    
    private let messagesManager = MessagesManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("New Message")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Spacer()
                    
                    Button("Send") {
                        Task {
                            await sendMessage()
                        }
                    }
                    .foregroundColor(canSend ? .blue : .gray)
                    .disabled(!canSend || isLoading)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                Divider()
                
                VStack(spacing: 16) {
                    // Group chat toggle
                    if selectedContacts.count > 1 {
                        HStack {
                            Toggle("Group Chat", isOn: $isGroupChat)
                                .font(.system(size: 16, weight: .medium))
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        if isGroupChat {
                            TextField("Group name (optional)", text: $groupTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                        }
                    }
                    
                    // Selected contacts
                    if !selectedContacts.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(selectedContacts, id: \.self) { contactId in
                                    if let contact = householdMembers.first(where: { $0.id == contactId }) {
                                        HStack(spacing: 8) {
                                            Text(getInitials(for: contact.name ?? "?"))
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 28, height: 28)
                                                .background(Color.blue)
                                                .clipShape(Circle())
                                            
                                            Text(contact.name ?? "Unknown")
                                                .font(.system(size: 14))
                                                .lineLimit(1)
                                            
                                            Button {
                                                selectedContacts.removeAll(where: { $0 == contactId })
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.gray)
                                                    .frame(width: 18, height: 18)
                                                    .background(Color.gray.opacity(0.2))
                                                    .clipShape(Circle())
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Divider()
                    
                    // Message input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MESSAGE")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        TextEditor(text: $messageText)
                            .frame(height: 100)
                            .padding(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Contacts list
                    VStack(alignment: .leading, spacing: 12) {
                        Text("HOUSEHOLD MEMBERS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(householdMembers.filter { $0.id != authManager.currentUser?.id }, id: \.id) { member in
                                    Button {
                                        toggleContact(member.id)
                                    } label: {
                                        HStack(spacing: 16) {
                                            ZStack {
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [Color.blue, Color.purple],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .frame(width: 40, height: 40)
                                                
                                                Text(getInitials(for: member.name ?? "?"))
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(member.name ?? "Unknown")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.primary)
                                                
                                                Text(member.email)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            if selectedContacts.contains(member.id) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.blue)
                                                    .font(.system(size: 20))
                                            } else {
                                                Image(systemName: "circle")
                                                    .foregroundColor(.gray)
                                                    .font(.system(size: 20))
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                }
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding()
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private var canSend: Bool {
        !selectedContacts.isEmpty && !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func getInitials(for name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].first?.uppercased() ?? "")\(components[1].first?.uppercased() ?? "")"
        } else {
            return "\(name.prefix(2).uppercased())"
        }
    }
    
    private func toggleContact(_ contactId: String) {
        if selectedContacts.contains(contactId) {
            selectedContacts.removeAll(where: { $0 == contactId })
        } else {
            selectedContacts.append(contactId)
        }
        
        // Auto-enable group chat for multiple contacts
        if selectedContacts.count > 1 {
            isGroupChat = true
        } else {
            isGroupChat = false
        }
    }
    
    private func sendMessage() async {
        guard let currentUser = authManager.currentUser,
              !selectedContacts.isEmpty,
              !currentHomeId.isEmpty else {
            errorMessage = "Missing required information"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Include current user in participants
            var allParticipants = selectedContacts
            allParticipants.append(currentUser.id)
            
            // Create conversation
            let conversation = try await messagesManager.createConversation(
                participants: allParticipants,
                homeId: currentHomeId,
                title: isGroupChat ? (groupTitle.isEmpty ? nil : groupTitle) : nil,
                isGroupChat: isGroupChat
            )
            
            // Send initial message
            let _ = try await messagesManager.sendMessage(
                conversationId: conversation.id,
                senderId: currentUser.id,
                content: messageText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            onMessageSent?(conversation)
            dismiss()
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    NewMessageView(householdMembers: [], currentHomeId: "")
}