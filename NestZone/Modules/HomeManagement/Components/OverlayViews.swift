import SwiftUI

struct SuccessOverlay: View {
    @Binding var show: Bool
    let message: String
    
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var animateCheck = false
    
    var body: some View {
        if show {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            show = false
                        }
                    }
                
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.green)
                            .scaleEffect(animateCheck ? 1.2 : 0.8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: animateCheck)
                    }
                    
                    Text(message)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(selectedTheme.colors(for: colorScheme).text)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedTheme.colors(for: colorScheme).cardBackground)
                        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                )
                .scaleEffect(show ? 1 : 0.8)
                .opacity(show ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: show)
            }
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.1)) {
                    animateCheck = true
                }
            }
        }
    }
}

struct ErrorOverlay: View {
    @Binding var show: Bool
    let message: String
    
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var animateError = false
    
    var body: some View {
        if show && !message.isEmpty {
            VStack {
                Spacer()
                
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                        .scaleEffect(animateError ? 1.1 : 0.9)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animateError)
                    
                    Text(message)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(selectedTheme.colors(for: colorScheme).text)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedTheme.colors(for: colorScheme).cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .offset(y: show ? 0 : 100)
                .opacity(show ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: show)
                .onAppear {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.1)) {
                        animateError = true
                    }
                }
            }
            .ignoresSafeArea(.keyboard)
        }
    }
}

#Preview("Success Overlay") {
    @State var showSuccess = true
    
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        SuccessOverlay(show: $showSuccess, message: "Account Created!")
    }
}

#Preview("Error Overlay") {
    @State var showError = true
    
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        ErrorOverlay(show: $showError, message: "Something went wrong. Please try again.")
    }
}