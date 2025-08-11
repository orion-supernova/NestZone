import SwiftUI

// MARK: - Actor Input Sheet
struct ActorInputSheet: View {
    let includeAdult: Bool
    let onActorSelected: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var actorName = ""
    @State private var isCreatingPoll = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    
                    Text("Search by Actor")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Enter the name of your favorite actor")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Input Field
                VStack(spacing: 16) {
                    TextField("Actor name (e.g., Tom Hanks)", text: $actorName)
                        .font(.system(size: 18, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                    
                    if !actorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            isCreatingPoll = true
                            onActorSelected(actorName.trimmingCharacters(in: .whitespacesAndNewlines))
                        } label: {
                            HStack(spacing: 8) {
                                if isCreatingPoll {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                Text(isCreatingPoll ? "Creating Poll..." : "Create Actor Poll")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isCreatingPoll)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Director Input Sheet
struct DirectorInputSheet: View {
    let includeAdult: Bool
    let onDirectorSelected: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var directorName = ""
    @State private var isCreatingPoll = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    
                    Text("Search by Director")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Enter the name of a film director")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Input Field
                VStack(spacing: 16) {
                    TextField("Director name (e.g., Christopher Nolan)", text: $directorName)
                        .font(.system(size: 18, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                                )
                        )
                    
                    if !directorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            isCreatingPoll = true
                            onDirectorSelected(directorName.trimmingCharacters(in: .whitespacesAndNewlines))
                        } label: {
                            HStack(spacing: 8) {
                                if isCreatingPoll {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                Text(isCreatingPoll ? "Creating Poll..." : "Create Director Poll")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isCreatingPoll)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Year Input Sheet
struct YearInputSheet: View {
    let includeAdult: Bool
    let onYearSelected: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var isCreatingPoll = false
    
    private let currentYear = Calendar.current.component(.year, from: Date())
    private let startYear = 1920
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    
                    Text("Search by Year")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Choose movies from a specific year")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Year Picker
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Text("Selected Year")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        Text("\(selectedYear)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                            )
                    }
                    
                    Picker("Year", selection: $selectedYear) {
                        ForEach(startYear...currentYear, id: \.self) { year in
                            Text("\(year)").tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    
                    Button {
                        isCreatingPoll = true
                        onYearSelected(selectedYear)
                    } label: {
                        HStack(spacing: 8) {
                            if isCreatingPoll {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            Text(isCreatingPoll ? "Creating Poll..." : "Create \(selectedYear) Poll")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isCreatingPoll)
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Decade Input Sheet
struct DecadeInputSheet: View {
    let includeAdult: Bool
    let onDecadeSelected: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDecade = 2020
    @State private var isCreatingPoll = false
    
    private let decades = [1920, 1930, 1940, 1950, 1960, 1970, 1980, 1990, 2000, 2010, 2020]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "calendar.circle.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    
                    Text("Search by Decade")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Choose movies from a specific decade")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Decade Selection
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Text("Selected Decade")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        Text("\(selectedDecade)s")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(decades, id: \.self) { decade in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedDecade = decade
                                }
                            } label: {
                                Text("\(decade)s")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(selectedDecade == decade ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        Group {
                                            if selectedDecade == decade {
                                                LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            } else {
                                                Color.clear
                                            }
                                        }
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(.indigo.opacity(0.3), lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    
                    Button {
                        isCreatingPoll = true
                        onDecadeSelected(selectedDecade)
                    } label: {
                        HStack(spacing: 8) {
                            if isCreatingPoll {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            Text(isCreatingPoll ? "Creating Poll..." : "Create \(selectedDecade)s Poll")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .indigo.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isCreatingPoll)
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}