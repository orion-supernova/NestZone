import SwiftUI

struct ModernNoteCreator: View {
    @EnvironmentObject private var viewModel: NotesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var noteText = ""
    @State private var selectedColorString: String = "yellow"
    @FocusState private var isTextFieldFocused: Bool
    
    let colorOptions: [(name: String, colorString: String)] = [
        ("Sunny Yellow", "yellow"),
        ("Sweet Pink", "pink"),
        ("Ocean Blue", "blue"),
        ("Fresh Green", "green"),
        ("Vibrant Orange", "orange"),
        ("Royal Purple", "purple")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main Content
                ScrollView {
                    VStack(spacing: 32) {
                        // Note Preview
                        notePreview
                            .padding(.top, 20)
                        
                        // Text Input
                        textInputSection
                        
                        // Color Selection
                        colorSelectionSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }
                .background(
                    LinearGradient(
                        colors: [
                            Color.yellow.opacity(0.08),
                            Color.yellow.opacity(0.03),
                            Color(.systemGray6).opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        Task {
                            await viewModel.addNote(text: noteText, color: selectedColorString)
                            dismiss()
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        noteText.isEmpty ? 
                        AnyShapeStyle(Color.secondary) :
                        AnyShapeStyle(LinearGradient(
                            colors: [selectedNoteColor.opacity(0.8), selectedNoteColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    )
                    .disabled(noteText.isEmpty)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
    
    private var selectedNoteColor: Color {
        return NoteColor.fromString(selectedColorString)
    }
    
    private var notePreview: some View {
        VStack(spacing: 16) {
            Text("Preview")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(noteText.isEmpty ? "Your note will appear here..." : noteText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .opacity(noteText.isEmpty ? 0.5 : 1.0)
                
                Spacer()
                
                HStack {
                    Text("- You")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.black.opacity(0.7))
                    
                    Spacer()
                    
                    Text("Now")
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(.black.opacity(0.5))
                }
            }
            .padding(16)
            .frame(width: 200, height: 160)
            .background(
                ZStack {
                    Rectangle()
                        .fill(selectedNoteColor)
                    
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
            .rotationEffect(.degrees(-2))
            .shadow(
                color: selectedNoteColor.opacity(0.3),
                radius: 8,
                x: 2,
                y: 4
            )
            .animation(.easeInOut(duration: 0.3), value: selectedNoteColor)
        }
    }
    
    private var textInputSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("What's on your mind?")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !noteText.isEmpty {
                    Text("\(noteText.count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(selectedNoteColor.opacity(0.2))
                        )
                }
            }
            
            TextEditor(text: $noteText)
                .focused($isTextFieldFocused)
                .font(.system(size: 16, weight: .medium))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 140)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    isTextFieldFocused ? selectedNoteColor.opacity(0.6) : selectedNoteColor.opacity(0.2),
                                    lineWidth: 2
                                )
                        )
                )
                .shadow(
                    color: selectedNoteColor.opacity(0.1),
                    radius: 10,
                    x: 0,
                    y: 4
                )
        }
    }
    
    private var colorSelectionSection: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Choose Color")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(selectedColorName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(selectedNoteColor.opacity(0.2))
                    )
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 20) {
                ForEach(colorOptions, id: \.colorString) { option in
                    ModernColorCircle(
                        color: NoteColor.fromString(option.colorString),
                        isSelected: selectedColorString == option.colorString
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedColorString = option.colorString
                        }
                        
                        let impactLight = UIImpactFeedbackGenerator(style: .light)
                        impactLight.impactOccurred()
                    }
                }
            }
        }
    }
    
    private var selectedColorName: String {
        return colorOptions.first { $0.colorString == selectedColorString }?.name ?? "Sunny Yellow"
    }
}

struct ModernColorCircle: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 50, height: 50)
                    .shadow(
                        color: color.opacity(0.4),
                        radius: isSelected ? 12 : 4,
                        x: 0,
                        y: isSelected ? 6 : 2
                    )
                
                if isSelected {
                    Circle()
                        .stroke(.white, lineWidth: 3)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .stroke(color.opacity(0.8), lineWidth: 2)
                        .frame(width: 62, height: 62)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
    }
}