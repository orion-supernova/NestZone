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
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.1))
                    )
                    .focused($isMessageFieldFocused)
                    .lineLimit(1...4)
                    .onSubmit {
                        if canSendMessage {
                            Task {
                                await onSendMessage()
                            }
                        }
                    }
                
                // Send button
                Button {
                    Task {
                        await onSendMessage()
                    }
                } label: {
                    SendButton(isEnabled: canSendMessage)
                }
                .disabled(!canSendMessage)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial)
        }
    }
}

struct SendButton: View {
    let isEnabled: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: isEnabled ? [Color.blue, Color.purple] : [Color.gray.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
            
            Image(systemName: "arrow.up")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .scaleEffect(isEnabled ? 1.0 : 0.8)
                .animation(.easeInOut(duration: 0.2), value: isEnabled)
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
                canSendMessage: true,
                onSendMessage: {
                    print("Send message tapped")
                }
            )
        }
    }
}

#Preview {
    ChatMessageInputPreview()
}