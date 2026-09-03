import SwiftUI

struct SwitchHomeSheet: View {
    @EnvironmentObject private var homeManager: HomeSelectionManager
    @EnvironmentObject private var authManager: ConvexAuthManager
    @Environment(\.dismiss) private var dismiss

    /// Home pending confirmation. Non-nil drives the confirmation dialog.
    @State private var homeToRemove: Home?
    @State private var isRemoving = false
    @State private var removeError: String?
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                selectedTheme.colors(for: colorScheme).background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.purple, .blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            Text(LocalizationManager.homeSelectionSwitchTitle)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(selectedTheme.colors(for: colorScheme).text)
                            
                            Text(LocalizationManager.homeSelectionSwitchSubtitle)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(selectedTheme.colors(for: colorScheme).textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 24)
                        
                        // Homes List
                        VStack(spacing: 12) {
                            ForEach(homeManager.availableHomes) { home in
                                SwitchHomeRow(
                                    home: home,
                                    isSelected: home.id == homeManager.selectedHomeId,
                                    onSelect: {
                                        homeManager.selectHome(home)
                                        dismiss()
                                    },
                                    onRemove: { homeToRemove = home }
                                )
                                .appear(step: 2)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
            .disabled(isRemoving)
            .confirmationDialog(
                confirmTitle,
                isPresented: Binding(
                    get: { homeToRemove != nil },
                    set: { if !$0 { homeToRemove = nil } }
                ),
                titleVisibility: .visible,
                presenting: homeToRemove
            ) { home in
                Button(isSoleMember(home) ? "Delete Home" : "Leave Home", role: .destructive) {
                    remove(home)
                }
                Button("Cancel", role: .cancel) { homeToRemove = nil }
            } message: { home in
                Text(confirmMessage(for: home))
            }
            .alert(
                "Couldn't remove home",
                isPresented: Binding(
                    get: { removeError != nil },
                    set: { if !$0 { removeError = nil } }
                )
            ) {
                Button("OK") { removeError = nil }
            } message: {
                Text(removeError ?? "")
            }
            .navigationTitle(LocalizationManager.homeSelectionSwitchTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizationManager.commonDoneButton) {
                        dismiss()
                    }
                    .foregroundColor(selectedTheme.colors(for: colorScheme).primary[0])
                }
            }
        }
    }

    private var confirmTitle: String {
        guard let home = homeToRemove else { return "" }
        return isSoleMember(home) ? "Delete \"\(home.name)\"?" : "Leave \"\(home.name)\"?"
    }

    private func isSoleMember(_ home: Home) -> Bool { home.members.count <= 1 }

    /// Spell out the consequence rather than saying "are you sure". Deleting the
    /// last membership cascades the home's entire contents server-side.
    private func confirmMessage(for home: Home) -> String {
        if isSoleMember(home) {
            return "You're the only member, so this deletes the home and everything in it — tasks, shopping list, notes, recipes, movie lists, polls and all chat history. This can't be undone."
        }
        return "You'll be removed from this home. Its content stays for the other \(home.members.count - 1) member\(home.members.count - 1 == 1 ? "" : "s")."
    }

    private func remove(_ home: Home) {
        // Re-entrancy guard: leaving twice would fire homes:leave twice, and the
        // second call throws "Not a member of this home" after the first wins.
        guard !isRemoving else { return }
        homeToRemove = nil
        isRemoving = true
        Task {
            do {
                try await homeManager.leaveHome(home, authManager: authManager)
            } catch {
                removeError = error.localizedDescription
            }
            isRemoving = false
        }
    }
}

struct SwitchHomeRow: View {
    let home: Home
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    var body: some View {
        // The card is two controls side by side, not one. A Button nested inside
        // another Button's label never receives taps, so the destructive action
        // has to live outside the selection button — which is also why the card
        // padding/background moved out here onto the HStack.
        HStack(spacing: 8) {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            withAnimation(.spring(response: 0.3)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3)) {
                    isPressed = false
                }
                onSelect()
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isSelected ? [.purple, .blue] : [.gray.opacity(0.3), .gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: isSelected ? "house.fill" : "house")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(home.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(selectedTheme.colors(for: colorScheme).text)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11, weight: .medium))
                        Text("\(home.members.count) \(home.members.count == 1 ? LocalizationManager.settingsMembersSingular : LocalizationManager.settingsMembersPlural)")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(selectedTheme.colors(for: colorScheme).textSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        }
        .buttonStyle(.plain)

        Button(role: .destructive) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            onRemove()
        } label: {
            Image(systemName: home.members.count <= 1 ? "trash" : "rectangle.portrait.and.arrow.right")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.red.opacity(0.85))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(home.members.count <= 1 ? "Delete home" : "Leave home"))
        }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedTheme.colors(for: colorScheme).cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isSelected ?
                                LinearGradient(
                                    colors: [.purple.opacity(0.5), .blue.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
            .shadow(
                color: isSelected ? Color.purple.opacity(0.2) : Color.black.opacity(0.05),
                radius: isSelected ? 12 : 6,
                x: 0,
                y: isSelected ? 6 : 3
            )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
    }
}

#Preview {
    SwitchHomeSheet()
        .environmentObject(HomeSelectionManager.shared)
}