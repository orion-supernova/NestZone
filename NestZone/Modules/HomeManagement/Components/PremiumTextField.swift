import SwiftUI

enum ValidationState {
    case neutral
    case valid
    case invalid
}

struct PremiumTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    let isRequired: Bool
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var validationState: ValidationState = .neutral
    var validationMessage: String = ""
    
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var isFocused = false
    @State private var animateIcon = false
    
    private var theme: ThemeColors {
        selectedTheme.colors(for: colorScheme)
    }
    
    private var borderColor: LinearGradient {
        switch validationState {
        case .valid:
            return LinearGradient(
                colors: [Color.green, Color.green.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .invalid:
            return LinearGradient(
                colors: [theme.destructive, theme.destructive.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .neutral:
            return isFocused ?
                LinearGradient(
                    colors: theme.primary,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [theme.textSecondary.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
        }
    }
    
    private var iconColor: LinearGradient {
        switch validationState {
        case .valid:
            return LinearGradient(
                colors: [Color.green],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .invalid:
            return LinearGradient(
                colors: [theme.destructive],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .neutral:
            return isFocused || !text.isEmpty ?
                LinearGradient(
                    colors: theme.primary,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [theme.textSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                
                if isRequired {
                    Text("*")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.destructive)
                }
            }
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
                    .scaleEffect(animateIcon ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: animateIcon)
                
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(keyboardType)
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
                } else {
                    TextField(placeholder, text: $text)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(keyboardType)
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
                
                // Validation icon
                if validationState != .neutral {
                    Image(systemName: validationState == .valid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(validationState == .valid ? .green : theme.destructive)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: validationState != .neutral ? 2 : (isFocused ? 2 : 1))
                    )
            )
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .shadow(
                color: validationState == .valid ? Color.green.opacity(0.2) :
                       validationState == .invalid ? theme.destructive.opacity(0.2) :
                       isFocused ? theme.primary[0].opacity(0.2) : .clear,
                radius: isFocused || validationState != .neutral ? 8 : 0,
                y: isFocused || validationState != .neutral ? 4 : 0
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: validationState)
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
            
            // Validation message
            if !validationMessage.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: validationState == .valid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(validationState == .valid ? .green : theme.destructive)
                    
                    Text(validationMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(validationState == .valid ? .green : theme.destructive)
                }
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

#Preview {
    @State var text1 = ""
    @State var text2 = "Sample text"
    @State var text3 = ""
    @State var secureText = ""
    
    VStack(spacing: 24) {
        PremiumTextField(
            title: "Email",
            placeholder: "Enter your email",
            text: $text1,
            icon: "envelope.fill",
            isRequired: true,
            keyboardType: .emailAddress
        )
        
        PremiumTextField(
            title: "Name",
            placeholder: "Enter your name",
            text: $text2,
            icon: "person.fill",
            isRequired: false,
            validationState: .valid,
            validationMessage: "Looks good!"
        )
        
        PremiumTextField(
            title: "Username",
            placeholder: "Choose a username",
            text: $text3,
            icon: "at",
            isRequired: true,
            validationState: .invalid,
            validationMessage: "Username already taken"
        )
        
        PremiumTextField(
            title: "Password",
            placeholder: "Enter password",
            text: $secureText,
            icon: "lock.fill",
            isRequired: true,
            isSecure: true
        )
    }
    .padding()
}