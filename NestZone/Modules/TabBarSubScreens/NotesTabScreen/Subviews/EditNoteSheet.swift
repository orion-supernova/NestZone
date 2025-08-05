import SwiftUI

struct EditNoteSheet: View {
    let note: PocketBaseNote
    @EnvironmentObject private var viewModel: NotesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String
    @State private var showingDeleteAlert = false
    @State private var tiltAngle: Double = -2  // Initial tilt
    
    init(note: PocketBaseNote) {
        self.note = note
        self._noteText = State(initialValue: note.description)
    }
    
    private var userName: String {
        return viewModel.getUserName(for: note)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.gray.opacity(0.2)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Header with close button
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.gray.opacity(0.2)))
                    }
                    
                    Spacer()
                    
                    Text("Edit Note")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Spacer()
                    
                    Button("Save") {
                        Task {
                            await viewModel.updateNote(note, text: noteText)
                            dismiss()
                        }
                    }
                    .disabled(noteText.isEmpty || noteText == note.description)
                    .opacity((noteText.isEmpty || noteText == note.description) ? 0.5 : 1.0)
                }
                .padding(.horizontal)
                
                // Note Preview - Realistic size with tilt
                VStack(alignment: .leading, spacing: 8) {
                    Text(noteText.isEmpty ? "Your note will appear here..." : noteText)
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
                        
                        Text(note.detailedDate)
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundStyle(.black.opacity(0.5))
                    }
                }
                .padding(16)
                .frame(width: 200, height: 160)
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
                .clipShape(RoundedRectangle(cornerRadius: 2))  // Flatter corners like real notes
                .rotationEffect(.degrees(tiltAngle))  // Tilt effect with state
                .onTapGesture {
                    // Change tilt direction on tap
                    withAnimation {
                        tiltAngle = tiltAngle == -2 ? 2 : -2
                    }
                }
                .shadow(
                    color: .black.opacity(0.15),
                    radius: 8,
                    x: 2,
                    y: 4
                )
                
                // Text Editor
                TextEditor(text: $noteText)
                    .font(.system(size: 16, weight: .medium))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 150)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        note.noteColor.opacity(0.3), // Use the note color from extension
                                        lineWidth: 2
                                    )
                            )
                    )
                
                // Delete Button
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Note")
                    }
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                    )
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.vertical, 20)
        }
        .alert("Delete Note", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteNote(note)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete this note? This action can't be undone.")
        }
    }
}

#Preview {
    EditNoteSheet(note: .init(
        id: "preview-id",
        description: "This is a sample note text that shows how the note will look when displayed in the preview section above the editor.",
        createdBy: "user-id",
        homeId: "home-id",
        image: nil,
        color: "purple",
        created: "2023-01-01T00:00:00.000Z",
        updated: "2023-01-01T00:00:00.000Z"
    ))
}