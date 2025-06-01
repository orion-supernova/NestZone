import SwiftUI

struct DashboardView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var tasksAppeared = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(LocalizationManager.text(.hello(name: "Sarah")))
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedTheme.colors(for: colorScheme).text)
                        Text(LocalizationManager.text(.tasksCount(count: 3)))
                            .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                    }
                    Spacer()
                    Text(Date(), style: .date)
                        .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                }
                .padding(.horizontal)
                
                Divider()
                    .background(selectedTheme.colors(for: colorScheme).textSecondary.opacity(0.2))
                    .padding(.horizontal)
                
                // Tasks Section with animation
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizationManager.text(.todaysTasks))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                        .padding(.horizontal)
                    
                    ForEach(Array(sampleTasks.enumerated()), id: \.element.id) { index, task in
                        TaskCard(task: task)
                            .offset(y: tasksAppeared ? 0 : 50)
                            .opacity(tasksAppeared ? 1 : 0)
                            .animation(
                                .spring(
                                    response: 0.3,
                                    dampingFraction: 0.8,
                                    blendDuration: 0
                                )
                                .delay(Double(index) * 0.1),
                                value: tasksAppeared
                            )
                    }
                }
                
                Divider()
                    .background(selectedTheme.colors(for: colorScheme).textSecondary.opacity(0.2))
                    .padding(.horizontal)
                
                // Statistics Section
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizationManager.text(.statistics))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                        .padding(.horizontal)
                    
                    StatisticsView()
                }
            }
            .padding(.vertical)
        }
        .background(selectedTheme.colors(for: colorScheme).background)
        .onAppear {
            withAnimation {
                tasksAppeared = true
            }
        }
    }
    
    // Sample data
    private var sampleTasks: [HouseTask] = [
        HouseTask(title: LocalizationManager.text(.kitchen), assignedTo: "Sarah", timeLeft: "2 saat", progress: 0.65, type: .cleaning),
        HouseTask(title: LocalizationManager.text(.shopping), assignedTo: "Mike", timeLeft: "Bugün", progress: 0.25, type: .shopping),
        HouseTask(title: LocalizationManager.text(.laundry), assignedTo: "Emma", timeLeft: "3 saat", progress: 0.8, type: .cleaning)
    ]
}

struct TaskCard: View {
    let task: HouseTask
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    var taskIcon: String {
        switch task.type {
        case .cleaning: return "spray.sparkle.fill"
        case .shopping: return "cart.fill"
        case .maintenance: return "wrench.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: taskIcon)
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: selectedTheme.colors(for: colorScheme).primary,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text(task.title)
                    .font(.headline)
                    .foregroundColor(selectedTheme.colors(for: colorScheme).text)
                
                Spacer()
                
                Text(task.timeLeft)
                    .font(.subheadline)
                    .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
            }
            
            Text(LocalizationManager.text(.assigned(name: task.assignedTo)))
                .font(.subheadline)
                .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
                .padding(.vertical, 4)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(selectedTheme.colors(for: colorScheme).textSecondary.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: selectedTheme.colors(for: colorScheme).primary,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * task.progress, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(selectedTheme.colors(for: colorScheme).cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: selectedTheme.colors(for: colorScheme).primary[0].opacity(0.1), radius: 5, y: 2)
        .padding(.horizontal)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(duration: 0.2), value: isPressed)
        .onTapGesture {
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()
            
            withAnimation {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isPressed = false
                }
            }
        }
    }
}

struct StatisticsView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 15) {
            StatBox(icon: "message.fill", title: "Mesaj", count: "12", change: "+3")
            StatBox(icon: "cart.fill", title: "Liste", count: "5", change: "+2")
            StatBox(icon: "wrench.fill", title: "Sorun", count: "2", change: "-1")
            StatBox(icon: "fork.knife", title: "Tarifler", count: "8", change: "+1")
        }
        .padding(.horizontal)
    }
}

struct StatBox: View {
    let icon: String
    let title: String
    let count: String
    let change: String
    @State private var isPressed = false
    @State private var iconBounce = false
    
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(selectedTheme.colors(for: colorScheme).primary[0])
                .scaleEffect(iconBounce ? 1.3 : 1.0)
                .animation(.interpolatingSpring(duration: 0.3, bounce: 0.5), value: iconBounce)
            
            Text(count)
                .font(.title3.weight(.semibold))
                .foregroundColor(selectedTheme.colors(for: colorScheme).text)
            
            Text(change)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    change.hasPrefix("+")
                        ? Color.green.opacity(0.2)
                        : Color.red.opacity(0.2)
                )
                .foregroundStyle(change.hasPrefix("+") ? .green : .red)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(selectedTheme.colors(for: colorScheme).cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: selectedTheme.colors(for: colorScheme).primary[0].opacity(0.1), radius: 5, y: 2)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(duration: 0.2), value: isPressed)
        .onTapGesture {
            let impactMed = UIImpactFeedbackGenerator(style: .light)
            impactMed.impactOccurred()
            
            withAnimation {
                isPressed = true
                iconBounce = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isPressed = false
                    iconBounce = false
                }
            }
        }
    }
}

struct WeeklyPerformanceView: View {
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(["Sarah", "Mike", "Alex", "Emma"].indices, id: \.self) { index in
                let isWinner = index == 0
                
                PerformanceRow(
                    name: ["Sarah", "Mike", "Alex", "Emma"][index],
                    xp: [850, 720, 680, 650][index],
                    rank: index
                )
                .background(
                    isWinner ?
                        LinearGradient(
                            colors: [
                                selectedTheme.colors(for: colorScheme).primary[0].opacity(0.2),
                                selectedTheme.colors(for: colorScheme).primary[0].opacity(0.1),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) : nil
                )
                .animation(.easeInOut(duration: 0.3), value: isWinner)
                
                if index < 3 {
                    Divider()
                        .background(selectedTheme.colors(for: colorScheme).textSecondary.opacity(0.2))
                }
            }
        }
        .padding()
        .background(selectedTheme.colors(for: colorScheme).cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: selectedTheme.colors(for: colorScheme).primary[0].opacity(0.1), radius: 5, y: 2)
        .padding(.horizontal)
    }
}

struct PerformanceRow: View {
    let name: String
    let xp: Int
    let rank: Int
    
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    
    var medalIcon: String {
        switch rank {
        case 0: return "👑"
        case 1: return "🥈"
        case 2: return "🥉"
        default: return "🏅"
        }
    }
    
    var body: some View {
        HStack {
            Text(medalIcon)
                .font(.title3)
            
            Text(name)
                .foregroundColor(selectedTheme.colors(for: colorScheme).text)
            
            Spacer()
            
            Text("\(xp) XP")
                .foregroundStyle(selectedTheme.colors(for: colorScheme).textSecondary)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 8)
    }
}
