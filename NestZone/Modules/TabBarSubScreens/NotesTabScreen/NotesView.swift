import SwiftUI

struct NotesView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: ConvexAuthManager
    @StateObject private var viewModel = NotesViewModel()
    @State private var showingNewNote = false
    @State private var selectedNote: PocketBaseNote?
    @State private var showingEditNote = false
    
    var body: some View {
        ZStack {
            // Background with colorful gradients
            RadialGradient(
                colors: [
                    selectedTheme.colors(for: colorScheme).background,
                    Color.purple.opacity(0.05),
                    Color.pink.opacity(0.03)
                ],
                center: .center,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            // Floating colorful shapes
            GeometryReader { geometry in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.1)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .offset(x: geometry.size.width - 60, y: 50)
                    .blur(radius: 30)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.pink.opacity(0.4), Color.purple.opacity(0.2)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                    .offset(x: 20, y: geometry.size.height * 0.7)
                    .blur(radius: 35)
            }
            
            ScrollView {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.notes.isEmpty {
                    emptyStateView
                } else {
                    notesGrid
                }
            }
        }
        .navigationTitle(LocalizationManager.notesScreenTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewNote = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple, Color.pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .refreshable {
            await viewModel.refreshData()
        }
        .fullScreenCover(isPresented: $showingNewNote) {
            ModernNoteCreator()
                .environmentObject(viewModel)
                .environmentObject(authManager)
        }
        .fullScreenCover(item: $selectedNote) { note in
            EditNoteSheet(note: note)
                .environmentObject(viewModel)
                .environmentObject(authManager)
        }
        .alert(LocalizationManager.commonErrorTitle, isPresented: .constant(viewModel.errorMessage != nil)) {
            Button(LocalizationManager.commonOkButton) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            viewModel.setAuthManager(authManager)
        }
    }
    
    private var loadingView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(0..<6, id: \.self) { _ in
                ShimmerNoteCard()
            }
        }
        .padding()
        .padding(.top, 40)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // Beautiful icon with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.15), Color.pink.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "note.text")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.purple, Color.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 12) {
                    Text(LocalizationManager.notesEmptyStateTitle)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.purple, Color.pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text(LocalizationManager.notesEmptyStateSubtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 32)
                }
                
                // Call to action button
                Button {
                    showingNewNote = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("Create Your First Note")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple, Color.pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: Color.purple.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .padding(.top, 8)
            }
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
    
    private var notesGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(viewModel.notes) { note in
                NoteCard(
                    note: note,
                    userName: viewModel.getUserName(for: note)
                ) {
                    // Tap to change tilt direction
                    print("Note tapped: \(note.id)")
                    // Handle tap action if needed
                }
                .onLongPressGesture {
                    // Long press to edit - only if user is owner
                    if let currentUserId = authManager.currentUser?.id {
                        if note.createdBy == currentUserId {
                            print("Note long pressed: \(note.id)")
                            selectedNote = note
                        } else {
                            print("User is not owner of note: \(note.id)")
                        }
                    }
                }
            }
        }
        .padding()
        .padding(.top, 20)
    }
}

#Preview {
    NavigationView {
        NotesView()
    }
}