import SwiftUI

struct NoteCard: View {
    let note: PocketBaseNote
    let userName: String
    let onTap: () -> Void
    @State private var isPressed = false
    @State private var rotationDirection = Double.random(in: -6...6)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.description)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.black)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
            
            Spacer()
            
            HStack {
                Text("- \(userName)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.black.opacity(0.7))
                
                Spacer()
                
                Text(note.formattedDate)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.black.opacity(0.5))
            }
        }
        .padding(16)
        .frame(width: 160, height: 160)
        .background(
            ZStack {
                Rectangle()
                    .fill(note.noteColor) // Use the note color from extension
                
                LinearGradient(
                    colors: [
                        .white.opacity(0.3),
                        .clear,
                        .black.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                LinearGradient(
                    colors: [
                        .white.opacity(0.1),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .rotationEffect(.degrees(rotationDirection))
        .shadow(
            color: .black.opacity(0.15),
            radius: 4,
            x: 1,
            y: 3
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            let impactMed = UIImpactFeedbackGenerator(style: .light)
            impactMed.impactOccurred()
            
            withAnimation {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isPressed = false
                }
                onTap()
            }
        }
    }
}

#Preview {
    NoteCard(
        note: .init(
            id: "preview-id",
            description: "This is a sample note text for preview purposes.",
            createdBy: "user-id",
            homeId: "home-id",
            image: nil,
            color: "purple",
            created: "2023-01-01T00:00:00.000Z",
            updated: "2023-01-01T00:00:00.000Z"
        ),
        userName: "user-name",
        onTap: {}
    )
}