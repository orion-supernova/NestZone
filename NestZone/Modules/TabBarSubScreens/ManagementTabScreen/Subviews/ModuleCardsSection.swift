import SwiftUI

struct ModuleCardsSection: View {
    let modules: [ModuleData]
    @Binding var showingShoppingView: Bool
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 20) {
            ForEach(Array(modules.enumerated()), id: \.element.type.id) { index, module in
                VibrantModuleCard(module: module, index: index, showingShoppingView: $showingShoppingView)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 100)
    }
}

#Preview {
    @State var showingShoppingView = false
    let sampleModules = [
        ModuleData(type: .shopping, itemCount: 5, recentActivity: "Added milk", progress: 0.65),
        ModuleData(type: .recipes, itemCount: 0, recentActivity: "Coming soon", progress: 0.0),
        ModuleData(type: .maintenance, itemCount: 2, recentActivity: "Fix sink", progress: 0.3),
        ModuleData(type: .finance, itemCount: 1, recentActivity: "Split bill", progress: 0.8)
    ]
    
    NavigationView {
        ScrollView {
            ModuleCardsSection(modules: sampleModules, showingShoppingView: $showingShoppingView)
        }
        .background(Color(.systemBackground))
    }
}