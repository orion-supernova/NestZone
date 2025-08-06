import SwiftUI

struct ReadReceiptsSheet: View {
    let message: PocketBaseMessage
    let readByUsers: [PocketBaseUser]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Read by \(readByUsers.count) people")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(formatMessageTime())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
                
                Divider()
                
                // Read receipts list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(readByUsers, id: \.id) { user in
                            ReadReceiptRow(user: user)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func formatMessageTime() -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: message.created) else {
            return "Unknown time"
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return "Sent \(displayFormatter.string(from: date))"
    }
}

struct ReadReceiptRow: View {
    let user: PocketBaseUser
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Text(getInitials())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name ?? "User")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Read")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Read indicator
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }
    
    private func getInitials() -> String {
        let name = user.name ?? "User"
        let components = name.split(separator: " ")
        
        if components.count >= 2 {
            let firstInitial = String(components[0].prefix(1))
            let lastInitial = String(components[1].prefix(1))
            return "\(firstInitial)\(lastInitial)".uppercased()
        } else if let firstChar = name.first {
            return String(firstChar).uppercased()
        }
        
        return "U"
    }
}

#Preview {
    ReadReceiptsSheet(
        message: PocketBaseMessage(
            id: "1",
            conversationId: "conv1",
            senderId: "user1",
            content: "Hello everyone!",
            messageType: .text,
            file: nil,
            readBy: ["user1", "user2", "user3"],
            created: "2025-01-01T12:00:00Z",
            updated: "2025-01-01T12:00:00Z"
        ),
        readByUsers: [
            PocketBaseUser(
                id: "user2",
                email: "sarah@example.com",
                name: "Sarah Johnson",
                avatar: nil,
                home_id: ["home1"],
                created: "2025-01-01T00:00:00Z",
                updated: "2025-01-01T00:00:00Z",
                verified: true,
                emailVisibility: false
            ),
            PocketBaseUser(
                id: "user3",
                email: "mike@example.com",
                name: "Mike Chen",
                avatar: nil,
                home_id: ["home1"],
                created: "2025-01-01T00:00:00Z",
                updated: "2025-01-01T00:00:00Z",
                verified: true,
                emailVisibility: false
            )
        ]
    )
}