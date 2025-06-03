import SwiftUI

struct LoginScreen: View {
    // MARK: - Properties
    @StateObject private var viewModel = LoginViewModel()
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @State private var email = ""
    @State private var password = ""
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 20) {
            Text("NestZone")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            
            Button {
                login()
            } label: {
                ZStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Login")
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .background(email.isEmpty || password.isEmpty || viewModel.isLoading ? Color.gray.opacity(0.5) : Color.blue)
            .cornerRadius(8)
            .disabled(email.isEmpty || password.isEmpty || viewModel.isLoading)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .alert(
            "Error",
            isPresented: .constant(viewModel.errorMessage != nil),
            presenting: viewModel.errorMessage,
            actions: { item in
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            }
        ) { item in
            Text(item)
        }
    }
    
    // MARK: - Private Methods
    private func login() {
        Task {
            await viewModel.login(authManager: authManager, email: email, password: password)
        }
    }
}

// MARK: - Preview
#Preview {
    LoginScreen()
        .environmentObject(PocketBaseAuthManager())
}
