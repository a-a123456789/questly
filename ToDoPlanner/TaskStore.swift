import Foundation
import SwiftUI

@MainActor
final class TaskStore: ObservableObject {
	@Published private(set) var tasks: [TodoItem] = []

	func tasks(for date: Date, dayPart: DayPart) -> [TodoItem] {
		let cal = Calendar.current
		return tasks
			.filter { item in
				guard let d = item.dueDate else { return false }
				let matchesDay = cal.isDate(d, inSameDayAs: date)
				if dayPart == .inbox { return matchesDay && item.dayPart == .inbox }
				return matchesDay && item.dayPart == dayPart
			}
			.sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }
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
	}

	func toggleDone(_ id: UUID) {
		guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
		tasks[idx].isDone.toggle()
	}

	func moveTask(_ id: UUID, to dayPart: DayPart, for date: Date) {
		guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
		tasks[idx].dayPart = dayPart
		tasks[idx].dueDate = dueDate(for: dayPart, on: date)
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
}

private extension String {
	var nilIfEmpty: String? {
		let t = trimmingCharacters(in: .whitespacesAndNewlines)
		return t.isEmpty ? nil : t
	}
}
