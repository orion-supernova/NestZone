import SwiftUI

struct SwipeCard: View {
    let movie: Movie
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void
    let onTap: () -> Void
    
    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var isDragging = false
    @State private var opacity: Double = 1.0
    
    private let threshold: CGFloat = 120
    private let rotationMultiplier: Double = 0.08
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Movie poster with consistent sizing
            if let url = movie.posterURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(LinearGradient(colors: [.purple.opacity(0.2), .pink.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.5))
                        )
                }
            } else {
                Rectangle()
                    .fill(LinearGradient(colors: [.purple.opacity(0.2), .pink.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.5))
                    )
            }
            
            // Swipe indicators (only show when dragging)
            if isDragging && abs(offset.width) > 30 {
                VStack {
                    HStack {
                        if offset.width < -30 {
                            VStack(spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 50, weight: .bold))
                                    .foregroundStyle(.red)
                                    .background(
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 60, height: 60)
                                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    )
                                Text("NOPE")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundStyle(.red)
                                    .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
                            }
                            .opacity(min(1.0, abs(offset.width) / threshold))
                            .scaleEffect(0.8 + min(0.3, abs(offset.width) / threshold * 0.3))
                        }
                        Spacer()
                        if offset.width > 30 {
                            VStack(spacing: 8) {
                                Image(systemName: "heart.circle.fill")
                                    .font(.system(size: 50, weight: .bold))
                                    .foregroundStyle(.green)
                                    .background(
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 60, height: 60)
                                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    )
                                Text("LIKE")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundStyle(.green)
                                    .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
                            }
                            .opacity(min(1.0, offset.width / threshold))
                            .scaleEffect(0.8 + min(0.3, offset.width / threshold * 0.3))
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 60)
                    Spacer()
                }
            }
            
            // Movie info overlay
            VStack(alignment: .leading, spacing: 8) {
                Text(movie.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 2, x: 1, y: 1)
                
                HStack(spacing: 8) {
                    if let year = movie.year {
                        Text("\(year)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.black.opacity(0.4)))
                    }
                    if !movie.genres.isEmpty {
                        Text(movie.genres.prefix(2).joined(separator: " • "))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.black.opacity(0.4)))
                    }
                }
                
                // Tap to see details hint
                HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Tap for details")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.8)], 
                    startPoint: .top, 
                    endPoint: .bottom
                )
                .frame(height: 140)
                .frame(maxHeight: .infinity, alignment: .bottom)
            )
        }
        .frame(width: 300, height: 450)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(
            color: isDragging ? .black.opacity(0.4) : .black.opacity(0.2),
            radius: isDragging ? 20 : 12,
            x: 0,
            y: isDragging ? 12 : 6
        )
        .offset(offset)
        .rotationEffect(.degrees(rotation))
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .opacity(opacity)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isDragging)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: offset)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: rotation)
        .onTapGesture {
            if !isDragging {
                onTap()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                        offset = value.translation
                        rotation = Double(value.translation.width) * rotationMultiplier
                    }
                    
                    let swipeDistance = abs(value.translation.width)
                    opacity = max(0.7, 1.0 - (swipeDistance / (threshold * 2)))
                    
                    if !isDragging {
                        isDragging = true
                    }
                }
                .onEnded { value in
                    isDragging = false
                    let swipeVelocity = value.predictedEndLocation.x - value.location.x
                    let isRightSwipe = value.translation.width > threshold || swipeVelocity > 300
                    let isLeftSwipe = value.translation.width < -threshold || swipeVelocity < -300
                    
                    if isRightSwipe {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            offset = CGSize(width: 600, height: -100)
                            rotation = 25
                            opacity = 0.0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSwipeRight()
                        }
                    } else if isLeftSwipe {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            offset = CGSize(width: -600, height: -100)
                            rotation = -25
                            opacity = 0.0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSwipeLeft()
                        }
                    } else {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                            offset = .zero
                            rotation = 0
                            opacity = 1.0
                        }
                    }
                }
        )
    }
}