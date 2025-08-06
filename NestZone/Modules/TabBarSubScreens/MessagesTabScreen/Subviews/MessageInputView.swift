import SwiftUI

struct ChatMessageInputView: View {
    @Binding var messageText: String
    @FocusState.Binding var isMessageFieldFocused: Bool
    
    let canSendMessage: Bool
    let onSendMessage: () async -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Message text field
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .font(.system(size: 16, weight: .regular))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .focused($isMessageFieldFocused)
                    .lineLimit(1...6)
                    .onSubmit {
                        if canSendMessage {
                            Task {
                                await onSendMessage()
                            }
                        }
                    }
                
                // Send button
                Button(action: {
                    Task {
                        await onSendMessage()
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(canSendMessage ? .blue : .gray)
                }
                .disabled(!canSendMessage)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
    }
}

// Preview wrapper to handle @FocusState
struct ChatMessageInputPreview: View {
    @State private var messageText = "Hello world!"
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack {
            Spacer()
            
            ChatMessageInputView(
                messageText: $messageText,
                isMessageFieldFocused: $isFocused,
                canSendMessage: !messageText.isEmpty,
                onSendMessage: {
                    print("Send message tapped")
                    messageText = ""
                }
            )
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    ChatMessageInputPreview()
}