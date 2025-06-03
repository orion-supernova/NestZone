import SwiftUI

struct NotesView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var notes: [NoteViewModel] = [
        NoteViewModel(text: "Please get some milk on your way home! 🥛", author: "Sarah", color: .yellow),
        NoteViewModel(text: "Dinner's in the fridge, just heat it up 🍝", author: "Mike", color: .pink),
        NoteViewModel(text: "Called the plumber, they're coming tomorrow at 10am 🔧", author: "Emma", color: .blue)
    ]
    @State private var newNoteText = ""
    @State private var showingNewNote = false
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(notes) { note in
                    NoteCard(note: note)
                }
            }
            .padding()
        }
        .background(selectedTheme.colors(for: colorScheme).background)
        .navigationTitle(LocalizationManager.text(.notes))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewNote = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showingNewNote) {
            NewNoteSheet(notes: $notes, isPresented: $showingNewNote)
        }
    }
}

struct NoteViewModel: Identifiable {
    let id = UUID()
    let text: String
    let author: String
    let color: Color
    let date = Date()
}

struct NoteCard: View {
    let note: NoteViewModel
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    @State private var rotationDirection = 1.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.black)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
            
            Spacer()
            
            HStack {
                Text("- \(note.author)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.black.opacity(0.7))
                
                Spacer()
                
                Text(note.date, style: .time)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.black.opacity(0.5))
            }
        }
        .padding(16)
        .frame(width: 160, height: 160)
        .background(
            ZStack {
                Rectangle()
                    .fill(note.color)
                
                LinearGradient(
                    colors: [
                        .white.opacity(0.15),
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
        .rotationEffect(.degrees(4 * rotationDirection))
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
                rotationDirection *= -1
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isPressed = false
                }
            }
        }
    }
}

private struct ColorCircle: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 30, height: 30)
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
            )
            .onTapGesture(perform: action)
    }
}

struct NewNoteSheet: View {
    @Binding var notes: [NoteViewModel]
    @Binding var isPresented: Bool
    @State private var noteText = ""
    @State private var selectedColor: Color = .yellow
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    let colors: [Color] = [.yellow, .pink, .blue, .green, .orange, .purple]
    
    var body: some View {
        NavigationView {
            Form {
                textSection
                colorSection
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                cancelButton
                addButton
            }
        }
    }
    
    private var textSection: some View {
        Section {
            TextEditor(text: $noteText)
                .frame(height: 100)
        }
    }
    
    private var colorSection: some View {
        Section("Color") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        ColorCircle(
                            color: color,
                            isSelected: selectedColor == color
                        ) {
                            selectedColor = color
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var cancelButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") {
                isPresented = false
            }
        }
    }
    
    private var addButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Add") {
                let note = NoteViewModel(text: noteText, author: "Sarah", color: selectedColor)
                notes.insert(note, at: 0)
                isPresented = false
            }
            .disabled(noteText.isEmpty)
        }
    }
}

#Preview {
    NotesView()
}
