import SwiftUI

struct MessagesView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @State private var conversations: [PocketBaseConversation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingNewMessage = false
    @State private var householdMembers: [PocketBaseUser] = []
    @State private var unreadCounts: [String: Int] = [:]
    @State private var currentHomeId: String?
    
    private let messagesManager = MessagesManager.shared
    
    var body: some View {
        ZStack {
            // Background with colorful gradients
            RadialGradient(
                colors: [
                    selectedTheme.colors(for: colorScheme).background,
                    Color.blue.opacity(0.05),
                    Color.cyan.opacity(0.03)
                ],
                center: .center,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            // Floating colorful shapes
            GeometryReader { geometry in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.1)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .offset(x: geometry.size.width - 60, y: 50)
                    .blur(radius: 30)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.4), Color.pink.opacity(0.2)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                    .offset(x: 20, y: geometry.size.height * 0.7)
                    .blur(radius: 35)
            }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Messages")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Spacer()
                    
                    Button {
                        showingNewMessage = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // Content
                if isLoading {
                    loadingView
                } else if conversations.isEmpty {
                    emptyStateView
                } else {
                    conversationsList
                }
            }
        }
        .onAppear {
            Task {
                await loadData()
            }
        }
        .refreshable {
            await loadData()
        }
        .fullScreenCover(isPresented: $showingNewMessage) {
            NewMessageView(
                householdMembers: householdMembers,
                currentHomeId: currentHomeId ?? ""
            ) { newConversation in
                conversations.insert(newConversation, at: 0)
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
    
    private func loadData() async {
        guard let currentUser = authManager.currentUser else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // First, fetch user's home (following the same pattern as other ViewModels)
            let pocketBase = PocketBaseManager.shared
            let userResponse: PocketBaseUser = try await pocketBase.request(
                endpoint: "/api/collections/users/records/\(currentUser.id)",
                requiresAuth: true,
                responseType: PocketBaseUser.self
            )
            
            guard let homeId = userResponse.home_id.first else {
                errorMessage = "No home found"
                isLoading = false
                return
            }
            
            currentHomeId = homeId
            
            // Load conversations and household members concurrently
            async let conversationsTask = messagesManager.fetchConversations(for: homeId)
            async let membersTask = messagesManager.fetchHouseholdMembers(for: homeId)
            
            let (fetchedConversations, fetchedMembers) = try await (conversationsTask, membersTask)
            
            conversations = fetchedConversations
            householdMembers = fetchedMembers
            
            // Load unread counts for each conversation
            for conversation in conversations {
                let unreadCount = try await messagesManager.getUnreadMessageCount(
                    for: conversation.id,
                    userId: currentUser.id
                )
                unreadCounts[conversation.id] = unreadCount
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 16) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 16)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 200, height: 14)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .redacted(reason: .placeholder)
            }
        }
        .padding(.top, 30)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue, Color.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("No Messages Yet")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Start a conversation with your household members")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showingNewMessage = true
            } label: {
                Text("Start a Conversation")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var conversationsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(conversations, id: \.id) { conversation in
                    ConversationCard(
                        conversation: conversation,
                        householdMembers: householdMembers,
                        unreadCount: unreadCounts[conversation.id] ?? 0,
                        currentUserId: authManager.currentUser?.id ?? ""
                    )
                    .padding(.horizontal, 24)
                    .onTapGesture {
                        // TODO: Navigate to chat detail view
                        print("Tapped conversation: \(conversation.id)")
                    }
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 100)
        }
    }
}

struct ConversationCard: View {
    let conversation: PocketBaseConversation
    let householdMembers: [PocketBaseUser]
    let unreadCount: Int
    let currentUserId: String
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
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
                    .frame(width: 50, height: 50)
                
                Text(getInitials())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                // Online indicator (placeholder for now)
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .offset(x: 18, y: 18)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(getTitle())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(selectedTheme.colors(for: colorScheme).text)
                    
                    Spacer()
                    
                    Text(formatDate())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(conversation.lastMessage ?? "No messages yet")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(selectedTheme.colors(for: colorScheme).textSecondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private func getInitials() -> String {
        if conversation.isGroupChat {
            return "GC"
        }
        
        // Get the other participant (not current user)
        let otherParticipantId = conversation.participants.first { $0 != currentUserId }
        let otherParticipant = householdMembers.first { $0.id == otherParticipantId }
        
        guard let name = otherParticipant?.name else { return "?" }
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].first?.uppercased() ?? "")\(components[1].first?.uppercased() ?? "")"
        } else {
            return "\(name.prefix(2).uppercased())"
        }
    }
    
    private func getTitle() -> String {
        if conversation.isGroupChat {
            return conversation.title ?? "Group Chat"
        } else {
            // Get the other participant (not current user)
            let otherParticipantId = conversation.participants.first { $0 != currentUserId }
            let otherParticipant = householdMembers.first { $0.id == otherParticipantId }
            return otherParticipant?.name ?? "Unknown User"
        }
    }
    
    private func formatDate() -> String {
        guard let lastMessageAt = conversation.lastMessageAt else {
            return ""
        }
        
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: lastMessageAt) else {
            return ""
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "HH:mm"
        return displayFormatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        MessagesView()
            .environmentObject(PocketBaseAuthManager())
    }
}