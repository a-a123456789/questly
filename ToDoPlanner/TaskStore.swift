import Foundation
import SwiftUI

@MainActor
final class TaskStore: ObservableObject {
	@Published private(set) var tasks: [TodoItem] = []
	@Published private(set) var lastPersistenceErrorMessage: String?
	private let persistence: TaskPersistence

	init(persistence: TaskPersistence? = nil) {
		let resolvedPersistence = persistence ?? TaskPersistence()
		self.persistence = resolvedPersistence
		do {
			self.tasks = try resolvedPersistence.loadTasks()
		} catch {
			self.tasks = []
			self.lastPersistenceErrorMessage = "Saved tasks could not be restored. Questly started with an empty local list."
		}
	}

	func tasks(for date: Date, dayPart: DayPart) -> [TodoItem] {
		let cal = Calendar.current
		return tasks
			.filter { item in
				guard let d = item.dueDate else { return false }
				let matchesDay = cal.isDate(d, inSameDayAs: date)
				if dayPart == .inbox { return matchesDay && item.dayPart == .inbox }
				return matchesDay && item.dayPart == dayPart
			}
			.sorted(by: taskSortComparator)
	}

	func addTask(
		title: String,
		details: String?,
		date: Date,
		dayPart: DayPart,
		priority: TaskPriority,
		rewardPoints: TaskRewardPoints
	) {
		let due = dueDate(for: dayPart, on: date)
		tasks.append(
			TodoItem(
				title: title,
				details: details?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
				isDone: false,
				dueDate: due,
				dayPart: dayPart,
				priority: priority,
				rewardPoints: rewardPoints
			)
		)
		persistTasks()
	}

	func toggleDone(_ id: UUID) {
		guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
		tasks[idx].isDone.toggle()
		persistTasks()
	}

	func updateTask(_ id: UUID, with draft: EditTaskDraft, for date: Date) {
		guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }

		let normalizedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !normalizedTitle.isEmpty else { return }

		tasks[idx].title = normalizedTitle
		tasks[idx].details = draft.details.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
		tasks[idx].priority = draft.priority
		tasks[idx].rewardPoints = draft.rewardPoints

		if tasks[idx].dayPart != draft.dayPart {
			tasks[idx].dayPart = draft.dayPart
			tasks[idx].dueDate = dueDate(for: draft.dayPart, on: date)
		}

		persistTasks()
	}

	func deleteTask(_ id: UUID) {
		guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
		tasks.remove(at: idx)
		persistTasks()
	}

	func moveTask(_ id: UUID, to dayPart: DayPart, for date: Date) {
		guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
		tasks[idx].dayPart = dayPart
		tasks[idx].dueDate = dueDate(for: dayPart, on: date)
		persistTasks()
	}

	func seedIfNeeded(for date: Date) {
		guard tasks.isEmpty else { return }
		addTask(title: "Review schedule", details: nil, date: date, dayPart: .morning, priority: .medium, rewardPoints: .p25)
		addTask(title: "Gym session", details: nil, date: date, dayPart: .midday, priority: .low, rewardPoints: .p15)
		addTask(title: "Plan tomorrow", details: nil, date: date, dayPart: .evening, priority: .high, rewardPoints: .p50)
	}

	private func dueDate(for dayPart: DayPart, on date: Date) -> Date {
		let cal = Calendar.current
		if dayPart == .inbox {
			return cal.startOfDay(for: date)
		}

		let hour = dayPart.hours.lowerBound
		return cal.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
	}

	private func persistTasks() {
		do {
			try persistence.saveTasks(tasks)
			lastPersistenceErrorMessage = nil
		} catch {
			lastPersistenceErrorMessage = "Changes are visible now, but Questly could not save them to local storage."
		}
	}

	private func taskSortComparator(_ lhs: TodoItem, _ rhs: TodoItem) -> Bool {
		if lhs.isDone != rhs.isDone {
			return rhs.isDone
		}

		let lhsDueDate = lhs.dueDate ?? .distantFuture
		let rhsDueDate = rhs.dueDate ?? .distantFuture
		if lhsDueDate != rhsDueDate {
			return lhsDueDate < rhsDueDate
		}

		if lhs.priority.sortRank != rhs.priority.sortRank {
			return lhs.priority.sortRank < rhs.priority.sortRank
		}

		let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
		if titleComparison != .orderedSame {
			return titleComparison == .orderedAscending
		}

		return lhs.id.uuidString < rhs.id.uuidString
	}
}

private extension String {
	var nilIfEmpty: String? {
		let t = trimmingCharacters(in: .whitespacesAndNewlines)
		return t.isEmpty ? nil : t
	}
}
