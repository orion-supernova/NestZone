import SwiftUI

struct QuickActionsSection: View {
    let onGenrePicker: () -> Void
    let onRandomMix: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Start")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
            
            HStack(spacing: 12) {
                Button(action: onGenrePicker) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("By Genre")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button(action: onRandomMix) {
                    HStack(spacing: 8) {
                        Image(systemName: "dice")
                        Text("Random Mix")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}