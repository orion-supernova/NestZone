import SwiftUI

struct NotesView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: PocketBaseAuthManager
    @StateObject private var viewModel = NotesViewModel()
    @State private var showingNewNote = false
    @State private var selectedNote: PocketBaseNote?
    @State private var showingEditNote = false
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.notes.isEmpty {
                emptyStateView
            } else {
                notesGrid
            }
        }
        .background(selectedTheme.colors(for: colorScheme).background)
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
        // Changed to use item-based presentation to avoid conditional content issues
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
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                // Clean icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "note.text")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.purple, Color.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 16) {
                    Text(LocalizationManager.notesEmptyStateTitle)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(LocalizationManager.notesEmptyStateSubtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            Spacer()
        }
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
                    // Access authManager correctly to get current user ID
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
    }
}

#Preview {
    NavigationView {
        NotesView()
    }
}