import Foundation

@MainActor
final class TaskRepositoryImpl: TaskRepository {
	private let store: TaskStore

	init(store: TaskStore) {
		self.store = store
	}

	func tasks(for date: Date, dayPart: DayPart) -> [TodoItem] {
		store.tasks(for: date, dayPart: dayPart)
	}

	func addTask(_ draft: NewTaskDraft, for date: Date) {
		store.addTask(
			title: draft.title,
			details: draft.details,
			date: date,
			dayPart: draft.dayPart,
			priority: draft.priority,
			rewardPoints: draft.rewardPoints
		)
	}

	func toggleDone(_ id: UUID) {
		store.toggleDone(id)
	}

	func moveTask(_ id: UUID, to dayPart: DayPart, for date: Date) {
		store.moveTask(id, to: dayPart, for: date)
	}

	func seedIfNeeded(for date: Date) {
		store.seedIfNeeded(for: date)
	}
}
