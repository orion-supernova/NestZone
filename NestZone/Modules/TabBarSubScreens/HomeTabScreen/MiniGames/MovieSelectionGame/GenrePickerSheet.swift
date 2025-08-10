import SwiftUI

struct GenrePickerSheet: View {
    let onPick: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGenres: Set<String> = []
    
    let genres = ["Action", "Adventure", "Comedy", "Drama", "Fantasy", "Horror", "Romance", "Sci-Fi", "Thriller", "Animation"]
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(genres, id: \.self) { genre in
                        HStack {
                            Button {
                                if selectedGenres.contains(genre) {
                                    selectedGenres.remove(genre)
                                } else {
                                    selectedGenres.insert(genre)
                                }
                            } label: {
                                HStack {
                                    Text(genre)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: selectedGenres.contains(genre) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedGenres.contains(genre) ? .green : .secondary)
                                }
                            }
                        }
                    }
                }
                
                if !selectedGenres.isEmpty {
                    VStack(spacing: 12) {
                        Text("Selected: \(selectedGenres.sorted().joined(separator: ", "))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                        
                        Button {
                            onPick(Array(selectedGenres))
                            dismiss()
                        } label: {
                            Text("Create Poll with \(selectedGenres.count) Genre\(selectedGenres.count == 1 ? "" : "s")")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Pick Genres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { 
                        selectedGenres.removeAll()
                    }
                    .disabled(selectedGenres.isEmpty)
                }
            }
        }
    }
}