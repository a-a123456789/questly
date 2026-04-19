import XCTest
@testable import ToDoPlanner

@MainActor
final class UseCaseTests: XCTestCase {
	func testGetWeekDates_returnsSevenDays() {
		let useCase = DefaultGetWeekDatesUseCase()
		let dates = useCase.execute(selectedDate: Date(timeIntervalSince1970: 0))
		XCTAssertEqual(dates.count, 7)
	}

	func testGetPlannerSections_composesTasksAndEvents() {
		let taskRepo = MockTaskRepository()
		let calRepo = MockCalendarRepository()
		let useCase = DefaultGetPlannerSectionsUseCase(taskRepository: taskRepo, calendarRepository: calRepo)

		let date = Date()
		let sections = useCase.execute(date: date)

		XCTAssertEqual(sections.count, DayPart.plannerParts.count)
		XCTAssertEqual(sections.first?.tasks.count, 1)
		XCTAssertEqual(sections.first?.events.count, 1)
	}

	func testGetPlannerSections_includesInboxSection() {
		let taskRepo = MockTaskRepository()
		let calRepo = MockCalendarRepository()
		let useCase = DefaultGetPlannerSectionsUseCase(taskRepository: taskRepo, calendarRepository: calRepo)

		let sections = useCase.execute(date: Date())

		XCTAssertTrue(sections.contains(where: { $0.part == .inbox }))
	}

	func testTaskStoreMoveTask_reanchorsMovedTaskToSelectedDate() throws {
		let store = TaskStore()
		let calendar = Calendar.current
		let sourceDate = Date(timeIntervalSince1970: 1_710_000_000)
		let targetDate = calendar.date(byAdding: .day, value: 1, to: sourceDate) ?? sourceDate

		store.addTask(
			title: "Inbox task",
			details: nil,
			date: sourceDate,
			dayPart: .inbox,
			priority: .medium,
			rewardPoints: .p25
		)

		let originalTask = try XCTUnwrap(store.tasks(for: sourceDate, dayPart: .inbox).first)
		store.moveTask(originalTask.id, to: .morning, for: targetDate)

		XCTAssertTrue(store.tasks(for: sourceDate, dayPart: .inbox).isEmpty)

		let movedTask = try XCTUnwrap(store.tasks(for: targetDate, dayPart: .morning).first)
		XCTAssertEqual(movedTask.id, originalTask.id)
		XCTAssertEqual(movedTask.dayPart, .morning)
		XCTAssertTrue(calendar.isDate(movedTask.dueDate ?? .distantPast, inSameDayAs: targetDate))
		XCTAssertEqual(calendar.component(.hour, from: movedTask.dueDate ?? .distantPast), DayPart.morning.hours.lowerBound)
	}
}

private final class MockTaskRepository: TaskRepository {
	var lastPersistenceErrorMessage: String? { nil }
	func allTasks() -> [TodoItem] { [] }
	func notificationAuthorizationStatus() async -> NotificationAuthorizationState { .notDetermined }

	func tasks(for date: Date, dayPart: DayPart) -> [TodoItem] {
		[TodoItem(title: "A", details: nil, dueDate: date, dayPart: dayPart, priority: .medium, rewardPoints: .p25)]
	}

	func addTask(_ draft: NewTaskDraft, for date: Date) {}
	func updateTask(_ id: UUID, with draft: EditTaskDraft, for date: Date) {}
	func resetLocalData() {}
	func deleteTask(_ id: UUID) {}
	func toggleDone(_ id: UUID) {}
	func moveTask(_ id: UUID, to dayPart: DayPart, for date: Date) {}
	func seedIfNeeded(for date: Date) {}
}

private final class MockCalendarRepository: CalendarRepository {
	func refresh(for date: Date) async {}
	func events(for part: DayPart) -> [PlannerEvent] {
		[PlannerEvent(id: "1", title: "Event", startDate: .now, endDate: .now, isAllDay: false)]
	}
}
