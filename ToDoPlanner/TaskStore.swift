import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class TaskStore: ObservableObject {
	@Published private(set) var tasks: [TodoItem] = []
	@Published private(set) var lastPersistenceErrorMessage: String?
	private let persistence: TaskPersistence
	private let userDefaults: UserDefaults
	private let reminderScheduler: TaskReminderScheduling
	private let hasSeededDefaultsKey = "questly.hasSeededDefaultTasks"

	init(
		persistence: TaskPersistence? = nil,
		userDefaults: UserDefaults = .standard
	) {
		let resolvedPersistence = persistence ?? TaskPersistence()
		self.persistence = resolvedPersistence
		self.userDefaults = userDefaults
		self.reminderScheduler = LocalTaskReminderScheduler(userDefaults: userDefaults)
		do {
			self.tasks = try resolvedPersistence.loadTasks()
			resynchronizeReminders()
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

	func allTasks() -> [TodoItem] {
		tasks
	}

	func notificationAuthorizationStatus() async -> NotificationAuthorizationState {
		await reminderScheduler.authorizationStatus()
	}

	func addTask(
		title: String,
		details: String?,
		date: Date,
		dayPart: DayPart,
		priority: TaskPriority,
		rewardPoints: TaskRewardPoints,
		reminderDate: Date? = nil,
		recurrence: TaskRecurrence = .none
	) {
		let due = dueDate(for: dayPart, on: date)
		let task = TodoItem(
			title: title,
			details: details?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
			isDone: false,
			dueDate: due,
			dayPart: dayPart,
			priority: priority,
			rewardPoints: rewardPoints,
			reminderDate: rebasedReminderDate(from: reminderDate, on: date),
			recurrence: recurrence
		)
		tasks.append(task)
		persistTasks()
		synchronizeReminder(for: task)
	}

	func toggleDone(_ id: UUID) {
		guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
		let wasDone = tasks[idx].isDone
		tasks[idx].isDone.toggle()
		tasks[idx].completedAt = tasks[idx].isDone ? Date() : nil
		let updatedTask = tasks[idx]
		if !wasDone, updatedTask.isDone {
			_ = generateNextOccurrenceIfNeeded(from: updatedTask)
		}
		persistTasks()
		synchronizeReminder(for: tasks[idx])
	}

	func updateTask(_ id: UUID, with draft: EditTaskDraft, for date: Date) {
		guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }

		let normalizedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !normalizedTitle.isEmpty else { return }

		tasks[idx].title = normalizedTitle
		tasks[idx].details = draft.details.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
		tasks[idx].priority = draft.priority
		tasks[idx].rewardPoints = draft.rewardPoints
		tasks[idx].reminderDate = rebasedReminderDate(from: draft.reminderDate, on: date)
		tasks[idx].recurrence = draft.recurrence

		if tasks[idx].dayPart != draft.dayPart {
			tasks[idx].dayPart = draft.dayPart
			tasks[idx].dueDate = dueDate(for: draft.dayPart, on: date)
		}

		persistTasks()
		synchronizeReminder(for: tasks[idx])
	}

	func deleteTask(_ id: UUID) {
		guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
		reminderScheduler.cancelReminder(for: id)
		tasks.remove(at: idx)
		persistTasks()
	}

	func resetLocalData() {
		let allIDs = tasks.map(\.id)
		allIDs.forEach { reminderScheduler.cancelReminder(for: $0) }
		tasks = []
		userDefaults.set(true, forKey: hasSeededDefaultsKey)
		persistTasks()
	}

	func moveTask(_ id: UUID, to dayPart: DayPart, for date: Date) {
		guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
		tasks[idx].dayPart = dayPart
		tasks[idx].dueDate = dueDate(for: dayPart, on: date)
		tasks[idx].reminderDate = rebasedReminderDate(from: tasks[idx].reminderDate, on: date)
		persistTasks()
		synchronizeReminder(for: tasks[idx])
	}

	func seedIfNeeded(for date: Date) {
		guard tasks.isEmpty, !userDefaults.bool(forKey: hasSeededDefaultsKey) else { return }
		addTask(title: "Review schedule", details: nil, date: date, dayPart: .morning, priority: .medium, rewardPoints: .p25)
		addTask(title: "Gym session", details: nil, date: date, dayPart: .midday, priority: .low, rewardPoints: .p15)
		addTask(title: "Plan tomorrow", details: nil, date: date, dayPart: .evening, priority: .high, rewardPoints: .p50)
		userDefaults.set(true, forKey: hasSeededDefaultsKey)
	}

	private func dueDate(for dayPart: DayPart, on date: Date) -> Date {
		let cal = Calendar.current
		if dayPart == .inbox {
			return cal.startOfDay(for: date)
		}

		let hour = dayPart.hours.lowerBound
		return cal.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
	}

	private func rebasedReminderDate(from reminderDate: Date?, on date: Date) -> Date? {
		guard let reminderDate else { return nil }
		let calendar = Calendar.current
		let timeComponents = calendar.dateComponents([.hour, .minute], from: reminderDate)
		let hour = timeComponents.hour ?? 9
		let minute = timeComponents.minute ?? 0
		return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)
	}

	private func generateNextOccurrenceIfNeeded(from task: TodoItem) -> TodoItem? {
		guard task.recurrence != .none, let currentDueDate = task.dueDate else { return nil }
		guard let nextDate = nextOccurrenceDate(after: currentDueDate, recurrence: task.recurrence) else { return nil }

		let nextDueDate = dueDate(for: task.dayPart, on: nextDate)
		guard !hasPendingRecurringOccurrence(matching: task, dueDate: nextDueDate) else { return nil }

		let nextTask = TodoItem(
			title: task.title,
			details: task.details,
			isDone: false,
			dueDate: nextDueDate,
			dayPart: task.dayPart,
			priority: task.priority,
			rewardPoints: task.rewardPoints,
			reminderDate: rebasedReminderDate(from: task.reminderDate, on: nextDate),
			recurrence: task.recurrence
		)
		tasks.append(nextTask)
		synchronizeReminder(for: nextTask)
		return nextTask
	}

	private func nextOccurrenceDate(after date: Date, recurrence: TaskRecurrence) -> Date? {
		let calendar = Calendar.current
		switch recurrence {
		case .none:
			return nil
		case .daily:
			return calendar.date(byAdding: .day, value: 1, to: date)
		case .weekdays:
			var candidate = date
			repeat {
				guard let next = calendar.date(byAdding: .day, value: 1, to: candidate) else { return nil }
				candidate = next
			} while calendar.isDateInWeekend(candidate)
			return candidate
		case .weekly:
			return calendar.date(byAdding: .day, value: 7, to: date)
		}
	}

	private func hasPendingRecurringOccurrence(matching source: TodoItem, dueDate: Date) -> Bool {
		let calendar = Calendar.current
		return tasks.contains { item in
			guard item.id != source.id else { return false }
			guard !item.isDone else { return false }
			guard item.recurrence == source.recurrence else { return false }
			guard item.dayPart == source.dayPart else { return false }
			guard item.priority == source.priority else { return false }
			guard item.rewardPoints == source.rewardPoints else { return false }
			guard item.title == source.title else { return false }
			guard item.details == source.details else { return false }
			guard let itemDueDate = item.dueDate else { return false }
			return calendar.isDate(itemDueDate, inSameDayAs: dueDate)
		}
	}

	private func synchronizeReminder(for task: TodoItem) {
		guard !task.isDone, let reminderDate = task.reminderDate, reminderDate > Date() else {
			reminderScheduler.cancelReminder(for: task.id)
			return
		}
		reminderScheduler.scheduleReminder(for: task)
	}

	private func resynchronizeReminders() {
		tasks.forEach { synchronizeReminder(for: $0) }
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

private protocol TaskReminderScheduling {
	func scheduleReminder(for task: TodoItem)
	func cancelReminder(for taskID: UUID)
	func authorizationStatus() async -> NotificationAuthorizationState
}

private final class LocalTaskReminderScheduler: TaskReminderScheduling {
	private let center: UNUserNotificationCenter
	private let userDefaults: UserDefaults
	private let authorizationRequestedKey = "questly.notifications.authorizationRequested"

	init(
		center: UNUserNotificationCenter = .current(),
		userDefaults: UserDefaults = .standard
	) {
		self.center = center
		self.userDefaults = userDefaults
	}

	func scheduleReminder(for task: TodoItem) {
		guard let reminderDate = task.reminderDate else {
			cancelReminder(for: task.id)
			return
		}

		requestAuthorizationIfNeeded { [weak self] granted in
			guard let self, granted else { return }

			let content = UNMutableNotificationContent()
			content.title = "Questly: \(task.title)"
			content.body = task.details?.nilIfEmpty ?? "Reminder for your \(task.dayPart.title.lowercased()) task."
			content.sound = .default

			let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
			let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
			let identifier = task.id.uuidString

			center.removePendingNotificationRequests(withIdentifiers: [identifier])
			let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
			center.add(request, withCompletionHandler: nil)
		}
	}

	func cancelReminder(for taskID: UUID) {
		let identifier = taskID.uuidString
		center.removePendingNotificationRequests(withIdentifiers: [identifier])
		center.removeDeliveredNotifications(withIdentifiers: [identifier])
	}

	func authorizationStatus() async -> NotificationAuthorizationState {
		await withCheckedContinuation { continuation in
			center.getNotificationSettings { settings in
				let status: NotificationAuthorizationState
				switch settings.authorizationStatus {
				case .authorized, .provisional, .ephemeral:
					status = .authorized
				case .notDetermined:
					status = .notDetermined
				case .denied:
					status = .denied
				@unknown default:
					status = .denied
				}
				continuation.resume(returning: status)
			}
		}
	}

	private func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
		if userDefaults.bool(forKey: authorizationRequestedKey) {
			center.getNotificationSettings { settings in
				let isAuthorized = settings.authorizationStatus == .authorized
					|| settings.authorizationStatus == .provisional
					|| settings.authorizationStatus == .ephemeral
				completion(isAuthorized)
			}
			return
		}

		center.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
			guard let self else {
				completion(granted)
				return
			}
			self.userDefaults.set(true, forKey: authorizationRequestedKey)
			completion(granted)
		}
	}
}
