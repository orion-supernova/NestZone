import SwiftUI

struct SearchHeader: View {
    @Binding var query: String
    let onSearch: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search movies to add to your list...", text: $query)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onSubmit { onSearch() }
            
            if !query.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

#Preview {
    @State var query = "The Matrix"
    
    SearchHeader(
        query: $query,
        onSearch: { print("Searching for: \(query)") },
        onClear: { query = "" }
    )
}