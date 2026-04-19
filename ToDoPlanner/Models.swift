import Foundation

enum DayPart: String, CaseIterable, Identifiable, Hashable, Codable {
	case morning
	case midday
	case evening
	case inbox

	var id: String { rawValue }

	static var plannerParts: [DayPart] { [.morning, .midday, .evening, .inbox] }
	static var sheetParts: [DayPart] { [.morning, .midday, .evening, .inbox] }

	var title: String {
		switch self {
		case .morning: "Morning"
		case .midday: "Midday"
		case .evening: "Evening"
		case .inbox: "Inbox"
		}
	}

	var timeRangeText: String {
		switch self {
		case .morning: "6AM – 12PM"
		case .midday: "12PM – 5PM"
		case .evening: "5PM – 10PM"
		case .inbox: ""
		}
	}

	/// Inclusive start hour, exclusive end hour, in local time.
	var hours: Range<Int> {
		switch self {
		case .morning: 6..<12
		case .midday: 12..<17
		case .evening: 17..<22
		case .inbox: 0..<24
		}
	}

	var defaultReminderHour: Int? {
		switch self {
		case .morning:
			8
		case .midday:
			13
		case .evening:
			18
		case .inbox:
			nil
		}
	}
}

enum TaskPriority: String, CaseIterable, Identifiable, Hashable, Codable {
	case low
	case medium
	case high

	var id: String { rawValue }

	var title: String {
		switch self {
		case .low: "Low"
		case .medium: "Medium"
		case .high: "High"
		}
	}

	var sortRank: Int {
		switch self {
		case .high: 0
		case .medium: 1
		case .low: 2
		}
	}
}

enum TaskRewardPoints: Int, CaseIterable, Identifiable, Hashable, Codable {
	case p15 = 15
	case p25 = 25
	case p50 = 50
	case p100 = 100

	var id: Int { rawValue }

	var title: String { "⚡ \(rawValue)" }
}

struct TodoItem: Identifiable, Hashable, Codable {
	let id: UUID
	var title: String
	var details: String?
	var isDone: Bool
	var dueDate: Date?
	var dayPart: DayPart
	var priority: TaskPriority
	var rewardPoints: TaskRewardPoints
	var reminderDate: Date?

	init(
		id: UUID = UUID(),
		title: String,
		details: String? = nil,
		isDone: Bool = false,
		dueDate: Date? = nil,
		dayPart: DayPart = .morning,
		priority: TaskPriority = .medium,
		rewardPoints: TaskRewardPoints = .p25,
		reminderDate: Date? = nil
	) {
		self.id = id
		self.title = title
		self.details = details
		self.isDone = isDone
		self.dueDate = dueDate
		self.dayPart = dayPart
		self.priority = priority
		self.rewardPoints = rewardPoints
		self.reminderDate = reminderDate
	}
}

struct PlannerEvent: Identifiable, Hashable {
	let id: String
	let title: String
	let startDate: Date
	let endDate: Date
	let isAllDay: Bool
}

struct NewTaskDraft: Hashable {
	let title: String
	let details: String
	let dayPart: DayPart
	let priority: TaskPriority
	let rewardPoints: TaskRewardPoints
	let reminderDate: Date?
}

struct EditTaskDraft: Hashable {
	let title: String
	let details: String
	let dayPart: DayPart
	let priority: TaskPriority
	let rewardPoints: TaskRewardPoints
	let reminderDate: Date?
}
