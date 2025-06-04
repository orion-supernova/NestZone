import SwiftUI

struct PremiumTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    let isRequired: Bool
    
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var isFocused = false
    @State private var animateIcon = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(selectedTheme.colors(for: colorScheme).textSecondary)
                
                if isRequired {
                    Text("*")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selectedTheme.colors(for: colorScheme).destructive)
                }
            }
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        isFocused || !text.isEmpty ?
                        LinearGradient(
                            colors: selectedTheme.colors(for: colorScheme).primary,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [selectedTheme.colors(for: colorScheme).textSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(animateIcon ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: animateIcon)
                
                TextField(placeholder, text: $text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(selectedTheme.colors(for: colorScheme).text)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            animateIcon = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                animateIcon = false
                            }
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedTheme.colors(for: colorScheme).cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isFocused ?
                                LinearGradient(
                                    colors: selectedTheme.colors(for: colorScheme).primary,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [selectedTheme.colors(for: colorScheme).textSecondary.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .shadow(
                color: isFocused ? selectedTheme.colors(for: colorScheme).primary[0].opacity(0.2) : .clear,
                radius: isFocused ? 8 : 0,
                y: isFocused ? 4 : 0
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isFocused = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidEndEditingNotification)) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isFocused = false
                }
            }
        }
    }
}