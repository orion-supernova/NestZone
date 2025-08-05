import SwiftUI

struct MessagesView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @StateObject private var viewModel = MessageListViewModel()
    @State private var showingNewMessage = false
    @State private var selectedConversation: PocketBaseConversation?
    @State private var currentHome: Home?
    
    private let pocketBase = PocketBaseManager.shared
    
    var body: some View {
        NavigationStack {
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
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.conversations.isEmpty {
                        emptyStateView
                    } else {
                        conversationsList
                    }
                }
            }
            .onAppear {
                print("DEBUG: MessagesView appeared")
                viewModel.setup(authManager: authManager)
                Task {
                    await loadCurrentHome()
                }
            }
            .refreshable {
                print("DEBUG: Pull to refresh triggered")
                await viewModel.refresh()
                await loadCurrentHome()
            }
            .fullScreenCover(isPresented: $showingNewMessage) {
                NewMessageView(
                    home: currentHome,
                    currentUserId: authManager.currentUser?.id ?? ""
                ) { newConversation in
                    viewModel.addNewConversation(newConversation)
                }
            }
            .navigationDestination(item: $selectedConversation) { conversation in
                ChatDetailView(
                    conversation: conversation,
                    currentUserId: authManager.currentUser?.id ?? ""
                ) {
                    // Refresh conversations when returning from chat
                    Task {
                        await viewModel.refresh()
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
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
            
            Text("Create a group chat to stay connected with your household")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showingNewMessage = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.message.fill")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Create Group Chat")
                        .font(.system(size: 16, weight: .semibold))
                }
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
                ForEach(viewModel.conversations, id: \.id) { conversation in
                    ConversationCard(
                        conversation: conversation,
                        unreadCount: viewModel.unreadCounts[conversation.id] ?? 0,
                        currentUserId: authManager.currentUser?.id ?? ""
                    )
                    .padding(.horizontal, 24)
                    .onTapGesture {
                        selectedConversation = conversation
                    }
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 100)
        }
    }
    
    private func loadCurrentHome() async {
        guard let currentUserId = authManager.currentUser?.id else { return }
        
        do {
            // Get user's home ID
            let userResponse: PocketBaseUser = try await pocketBase.request(
                endpoint: "/api/collections/users/records/\(currentUserId)",
                requiresAuth: true,
                responseType: PocketBaseUser.self
            )
            
            guard let homeId = userResponse.home_id.first else {
                print("DEBUG: MessagesView - User has no home")
                return
            }
            
            // Fetch the home details
            let home: Home = try await pocketBase.request(
                endpoint: "/api/collections/homes/records/\(homeId)",
                requiresAuth: true,
                responseType: Home.self
            )
            
            await MainActor.run {
                currentHome = home
                print("DEBUG: MessagesView - Loaded home: \(home.name)")
            }
            
        } catch {
            print("DEBUG: MessagesView - Error loading home: \(error)")
        }
    }
}

struct ConversationCard: View {
    let conversation: PocketBaseConversation
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
                
                // Show unread indicator
                if unreadCount > 0 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .offset(x: 18, y: 18)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
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
                        .font(.system(size: 14, weight: unreadCount > 0 ? .semibold : .regular))
                        .foregroundColor(unreadCount > 0 ? selectedTheme.colors(for: colorScheme).text : selectedTheme.colors(for: colorScheme).textSecondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if unreadCount > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
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
        return "HM"
    }
    
    private func getTitle() -> String {
        if conversation.isGroupChat {
            return conversation.title ?? "Household Chat"
        } else {
            return "Direct Message"
        }
    }
    
    private func formatDate() -> String {
        guard let lastMessageAt = conversation.lastMessageAt,
              !lastMessageAt.isEmpty else {
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