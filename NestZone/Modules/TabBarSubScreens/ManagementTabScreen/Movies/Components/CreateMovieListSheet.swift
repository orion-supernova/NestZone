import SwiftUI

struct CreateMovieListSheet: View {
    let onCreate: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                headerView
                
                formFields
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .background(
                RadialGradient(
                    colors: [
                        Color(.systemBackground),
                        Color.purple.opacity(0.03),
                        Color.pink.opacity(0.02)
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 800
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines), description.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundStyle(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.purple)
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "plus.rectangle.on.folder")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                
                Spacer()
            }
            
            Text("Create Movie List")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Organize movies by theme, genre, or any criteria you want")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
    
    private var formFields: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("List Name")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                
                TextField("e.g., Horror Classics, Rom-Com Favorites", text: $name)
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(.secondary.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Description (Optional)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                
                TextField("Describe what this list is for...", text: $description, axis: .vertical)
                    .lineLimit(3...6)
                    .textInputAutocapitalization(.sentences)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(.secondary.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
        }
    }
}

#Preview {
    CreateMovieListSheet { name, description in
        print("Creating list: \(name) - \(description)")
    }
}