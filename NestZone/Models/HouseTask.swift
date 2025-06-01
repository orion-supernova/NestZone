import Foundation

struct HouseTask: Identifiable {
    let id: UUID = UUID()
    let title: String
    let assignedTo: String
    let timeLeft: String
    var progress: Double
    let type: TaskType
    
    enum TaskType {
        case cleaning
        case shopping
        case maintenance
    }
}