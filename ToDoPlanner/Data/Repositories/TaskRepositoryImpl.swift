import Foundation

@MainActor
final class TaskRepositoryImpl: TaskRepository {
	private let store: TaskStore

	init(store: TaskStore) {
		self.store = store
	}

	var lastPersistenceErrorMessage: String? {
		store.lastPersistenceErrorMessage
	}

	func notificationAuthorizationStatus() async -> NotificationAuthorizationState {
		await store.notificationAuthorizationStatus()
	}

	func allTasks() -> [TodoItem] {
		store.allTasks()
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
			rewardPoints: draft.rewardPoints,
			reminderDate: draft.reminderDate,
			recurrence: draft.recurrence
		)
	}

	func updateTask(_ id: UUID, with draft: EditTaskDraft, for date: Date) {
		store.updateTask(id, with: draft, for: date)
	}

	func resetLocalData() {
		store.resetLocalData()
	}

	func deleteTask(_ id: UUID) {
		store.deleteTask(id)
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
