import Foundation

protocol TaskRepository {
    var lastPersistenceErrorMessage: String? { get }
    func tasks(for date: Date, dayPart: DayPart) -> [TodoItem]
    func addTask(_ draft: NewTaskDraft, for date: Date)
    func updateTask(_ id: UUID, with draft: EditTaskDraft, for date: Date)
    func toggleDone(_ id: UUID)
    func seedIfNeeded(for date: Date)
    func moveTask(_ id: UUID, to dayPart: DayPart, for date: Date)
}
