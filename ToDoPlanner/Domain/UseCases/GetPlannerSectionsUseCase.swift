import Foundation

struct PlannerSection: Hashable {
	let part: DayPart
	let tasks: [TodoItem]
	let events: [PlannerEvent]
}

protocol GetPlannerSectionsUseCase {
	@MainActor
	func execute(date: Date) -> [PlannerSection]
}

struct DefaultGetPlannerSectionsUseCase: GetPlannerSectionsUseCase {
	let taskRepository: TaskRepository
	let calendarRepository: CalendarRepository

	@MainActor
	func execute(date: Date) -> [PlannerSection] {
		DayPart.plannerParts.map { part in
			PlannerSection(
				part: part,
				tasks: taskRepository.tasks(for: date, dayPart: part),
				events: Array(calendarRepository.events(for: part).prefix(2))
			)
		}
	}
}
