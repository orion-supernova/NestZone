import SwiftUI

struct CustomListRow: View {
    let list: MovieList
    let movieCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(list.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let description = list.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)
                    }
                }
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(movieCount)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.purple)
                    
                    Text("movies")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.purple.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

#Preview {
    let sampleList = MovieList(
        id: "1",
        homeId: "home1",
        name: "Horror Classics",
        description: "The best scary movies of all time",
        type: .custom,
        isPreset: false,
        created: "",
        updated: ""
    )
    
    CustomListRow(
        list: sampleList,
        movieCount: 23,
        action: { print("Custom list tapped") }
    )
    .padding()
}