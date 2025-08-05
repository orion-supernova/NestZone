import SwiftUI

struct NewMessageView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @State private var messageText = ""
    @State private var groupTitle = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let home: Home?
    let currentUserId: String
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
                    
                    Text("New Group Chat")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Spacer()
                    
                    Button("Create") {
                        Task {
                            await createGroupChat()
                        }
                    }
                    .foregroundColor(canCreate ? .blue : .gray)
                    .disabled(!canCreate || isLoading)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                Divider()
                
                VStack(spacing: 24) {
                    // Info Section
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple, Color.cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.blue.opacity(0.4), radius: 12, x: 0, y: 6)
                            
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Household Group Chat")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            if let home = home {
                                Text("This chat will include all \(home.members.count) members of \(home.name)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            } else {
                                Text("This chat will include all household members")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        }
                    }
                    .padding(.top, 32)
                    
                    // Group name input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GROUP NAME (OPTIONAL)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        TextField("e.g., Family Chat, House Updates...", text: $groupTitle)
                            .font(.system(size: 16, weight: .medium))
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.thinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                    }
                    .padding(.horizontal)
                    
                    // Initial message input - Simple approach to avoid constraints
                    VStack(alignment: .leading, spacing: 12) {
                        Text("FIRST MESSAGE")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        TextField("Say hello to your household...", text: $messageText)
                            .font(.system(size: 16, weight: .medium))
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.thinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.sentences)
                    }
                    .padding(.horizontal)
                    
                    // Member count info
                    if let home = home {
                        HStack(spacing: 12) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                            
                            Text("\(home.members.count) household members will be added to this chat")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.05))
                        )
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                
                if isLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        
                        Text("Creating group chat...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 20)
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
    
    private var canCreate: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func createGroupChat() async {
        guard let currentUser = authManager.currentUser,
              let home = home else {
            errorMessage = "Missing required information"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Create conversation with all household members
            let allParticipants = home.members // This includes current user
            
            print("DEBUG: Creating conversation with participants: \(allParticipants)")
            print("DEBUG: Home ID: \(home.id)")
            print("DEBUG: Group title: \(groupTitle.isEmpty ? "\(home.name) Chat" : groupTitle)")
            
            let conversation = try await messagesManager.createConversation(
                participants: allParticipants,
                homeId: home.id,
                title: groupTitle.isEmpty ? "\(home.name) Chat" : groupTitle,
                isGroupChat: true
            )
            
            print("DEBUG: Conversation created with ID: \(conversation.id)")
            
            // Send initial message
            let message = try await messagesManager.sendMessage(
                conversationId: conversation.id,
                senderId: currentUser.id,
                content: messageText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            print("DEBUG: Message sent with ID: \(message.id)")
            
            onMessageSent?(conversation)
            dismiss()
            
        } catch {
            print("DEBUG: Error creating group chat: \(error)")
            if let pocketBaseError = error as? PocketBaseManager.PocketBaseError {
                errorMessage = pocketBaseError.localizedDescription
            } else {
                errorMessage = "Failed to create group chat: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
}

#Preview {
    NewMessageView(home: nil, currentUserId: "")
}