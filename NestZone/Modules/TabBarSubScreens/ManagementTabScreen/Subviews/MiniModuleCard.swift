import SwiftUI

struct MiniModuleCard: View {
    let title: String
    let count: String
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: 4) {
            Text(count)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(gradient[0].opacity(0.1))
        )
    }
}

#Preview {
    HStack {
        MiniModuleCard(
            title: "Shopping",
            count: "5",
            gradient: [.green, .mint]
        )
        
        MiniModuleCard(
            title: "Notes",
            count: "12",
            gradient: [.blue, .cyan]
        )
        
        MiniModuleCard(
            title: "Tasks",
            count: "3",
            gradient: [.purple, .pink]
        )
    }
    .padding()
}