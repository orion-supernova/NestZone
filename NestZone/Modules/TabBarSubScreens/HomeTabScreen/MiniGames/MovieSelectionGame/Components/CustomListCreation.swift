import SwiftUI

struct CustomListCreation: View {
    @Binding var customList: [Movie]
    @Binding var customListTitle: String
    let onAddMovies: () -> Void
    let onStartPoll: () -> Void
    let onClearList: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Create Custom List")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                
                Spacer()
                
                if !customList.isEmpty {
                    Text("\(customList.count) movies")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.green.opacity(0.2)))
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // Title Field
                TextField("Enter list title (e.g., Friday Night Picks)", text: $customListTitle)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(.secondary.opacity(0.2), lineWidth: 1)
                            )
                    )
                
                // Search & Actions
                HStack(spacing: 10) {
                    Button(action: onAddMovies) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.magnifyingglass")
                            Text("Add Movies")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(LinearGradient(colors: [.mint, .green], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    if !customList.isEmpty {
                        Button(action: onStartPoll) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Start Poll")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        Button(action: onClearList) {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.red)
                                .padding(10)
                                .background(Circle().fill(.red.opacity(0.1)))
                        }
                    }
                }
                
                // Movie List Preview
                if !customList.isEmpty {
                    CustomMoviePreview(movies: customList) { movie in
                        if let index = customList.firstIndex(where: { $0.id == movie.id }) {
                            customList.remove(at: index)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.green.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

struct CustomMoviePreview: View {
    let movies: [Movie]
    let onRemove: (Movie) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Movies:")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(movies) { movie in
                        VStack(spacing: 6) {
                            if let url = movie.posterURL {
                                AsyncImage(url: url) { img in
                                    img
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                }
                                .frame(width: 50, height: 75)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 50, height: 75)
                            }
                            
                            Text(movie.title)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(2)
                                .frame(width: 50)
                                .multilineTextAlignment(.center)
                        }
                        .onTapGesture {
                            onRemove(movie)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.top, 8)
    }
}