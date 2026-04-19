import Foundation
import SwiftUI

struct HomeDayItem: Identifiable, Hashable {
    let date: Date
    let weekdayText: String
    let dayText: String
    let isSelected: Bool

    var id: Date { date }
}

struct HomeTaskRowModel: Identifiable, Hashable {
    let id: UUID
    let title: String
    let isDone: Bool
}

struct HomeEventRowModel: Identifiable, Hashable {
    let id: String
    let title: String
    let timeText: String
}

enum HomeSectionEntry: Identifiable, Hashable {
    case task(HomeTaskRowModel)
    case event(HomeEventRowModel)

    var id: String {
        switch self {
        case .task(let task):
            "task-\(task.id.uuidString)"
        case .event(let event):
            "event-\(event.id)"
        }
    }
}

struct HomeSectionModel: Identifiable, Hashable {
    let part: DayPart
    let title: String
    let timeRangeText: String
    let iconURL: URL
    let entries: [HomeSectionEntry]

    var id: DayPart { part }
}

@MainActor
final class NewTaskViewModel: ObservableObject, Identifiable {
    let id = UUID()
    let date: Date
    private let onAdd: (NewTaskDraft) -> Void

    @Published var title: String = ""
    @Published var description: String = ""
    @Published var selectedWhen: DayPart
    @Published var selectedPriority: TaskPriority = .medium
    @Published var selectedPoints: TaskRewardPoints = .p25

    init(defaultDayPart: DayPart, date: Date, onAdd: @escaping (NewTaskDraft) -> Void) {
        self.selectedWhen = defaultDayPart
        self.date = date
        self.onAdd = onAdd
    }

    var isSubmissionEnabled: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var whenOptions: [DayPart] {
        DayPart.allCases
    }

    var priorityOptions: [TaskPriority] {
        TaskPriority.allCases
    }

    var pointsOptions: [TaskRewardPoints] {
        TaskRewardPoints.allCases
    }

    func makeDraft() -> NewTaskDraft? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }

        return NewTaskDraft(
            title: trimmedTitle,
            details: description.trimmingCharacters(in: .whitespacesAndNewlines),
            dayPart: selectedWhen,
            priority: selectedPriority,
            rewardPoints: selectedPoints
        )
    }

    @discardableResult
    func addTask() -> Bool {
        guard let draft = makeDraft() else { return false }
        onAdd(draft)
        return true
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var selectedDate: Date
    @Published var newTaskViewModel: NewTaskViewModel?

    private let taskRepository: TaskRepository
    private let calendarRepository: CalendarRepository
    private let getPlannerSections: GetPlannerSectionsUseCase
    private let getWeekDates: GetWeekDatesUseCase
    private var hasLoaded = false

    init(
        selectedDate: Date = .now,
        newTaskViewModel: NewTaskViewModel? = nil,
        taskRepository: TaskRepository,
        calendarRepository: CalendarRepository,
        getPlannerSections: GetPlannerSectionsUseCase,
        getWeekDates: GetWeekDatesUseCase
    ) {
        self.selectedDate = selectedDate
        self.newTaskViewModel = newTaskViewModel
        self.taskRepository = taskRepository
        self.calendarRepository = calendarRepository
        self.getPlannerSections = getPlannerSections
        self.getWeekDates = getWeekDates
    }

    convenience init(
        selectedDate: Date = .now,
        newTaskViewModel: NewTaskViewModel? = nil
    ) {
        let store = TaskStore()
        let calendarClient = CalendarClient()
        let taskRepository = TaskRepositoryImpl(store: store)
        let calendarRepository = CalendarRepositoryImpl(client: calendarClient)
        self.init(
            selectedDate: selectedDate,
            newTaskViewModel: newTaskViewModel,
            taskRepository: taskRepository,
            calendarRepository: calendarRepository,
            getPlannerSections: DefaultGetPlannerSectionsUseCase(
                taskRepository: taskRepository,
                calendarRepository: calendarRepository
            ),
            getWeekDates: DefaultGetWeekDatesUseCase()
        )
    }

    var weekdayText: String {
        selectedDate.formatted(.dateTime.weekday(.wide))
    }

    var fullDateText: String {
        selectedDate.formatted(.dateTime.month(.wide).day().year())
    }

    var pointsText: String {
        "1,834"
    }

    var dayItems: [HomeDayItem] {
        let calendar = Calendar.current
        return getWeekDates.execute(selectedDate: selectedDate).map { date in
            return HomeDayItem(
                date: date,
                weekdayText: date.formatted(.dateTime.weekday(.abbreviated)).uppercased(),
                dayText: date.formatted(.dateTime.day()),
                isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
            )
        }
    }

    var sections: [HomeSectionModel] {
        getPlannerSections.execute(date: selectedDate).map { section in
            let taskEntries = section.tasks.map {
                HomeSectionEntry.task(
                    HomeTaskRowModel(id: $0.id, title: $0.title, isDone: $0.isDone)
                )
            }
            let eventEntries = section.events.map {
                HomeSectionEntry.event(
                    HomeEventRowModel(
                        id: $0.id,
                        title: $0.title,
                        timeText: eventTimeText(for: $0)
                    )
                )
            }

            return HomeSectionModel(
                part: section.part,
                title: section.part.title,
                timeRangeText: section.part.timeRangeText,
                iconURL: iconURL(for: section.part),
                entries: taskEntries + eventEntries
            )
        }
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        taskRepository.seedIfNeeded(for: selectedDate)
        refreshCalendar(for: selectedDate)
        objectWillChange.send()
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        taskRepository.seedIfNeeded(for: date)
        refreshCalendar(for: date)
    }

    func toggleDone(_ id: UUID) {
        taskRepository.toggleDone(id)
        objectWillChange.send()
    }

    func addTask(_ draft: NewTaskDraft) {
        taskRepository.addTask(draft, for: selectedDate)
        objectWillChange.send()
    }

    func moveTask(_ id: UUID, to dayPart: DayPart) {
        taskRepository.moveTask(id, to: dayPart, for: selectedDate)
        objectWillChange.send()
    }

    func presentNewTask(for part: DayPart) {
        newTaskViewModel = NewTaskViewModel(defaultDayPart: part, date: selectedDate) { [weak self] draft in
            self?.addTask(draft)
            self?.dismissNewTask()
        }
    }

    private func dismissNewTask() {
        newTaskViewModel = nil
    }

    private func refreshCalendar(for date: Date) {
        guard !isRunningInPreviews else { return }
        Task {
            await calendarRepository.refresh(for: date)
            objectWillChange.send()
        }
    }

    private var isRunningInPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private func eventTimeText(for event: PlannerEvent) -> String {
        guard !event.isAllDay else { return "All day" }
        return "\(event.startDate.formatted(.dateTime.hour().minute())) – \(event.endDate.formatted(.dateTime.hour().minute()))"
    }
}

private func iconURL(for part: DayPart) -> URL {
    switch part {
    case .morning:
        URL(string: "https://www.figma.com/api/mcp/asset/c9beefae-a231-42f5-b502-dbe147ee2387")!
    case .midday:
        URL(string: "https://www.figma.com/api/mcp/asset/3e9c3fec-0fe7-4274-a6fe-6d60c6b2b092")!
    case .evening:
        URL(string: "https://www.figma.com/api/mcp/asset/ffd2bbae-40a9-4163-b0f4-71635f9770ce")!
    case .inbox:
        URL(string: "https://www.figma.com/api/mcp/asset/90131a9e-37e6-4d41-a19c-ec59ab7c4047")!
    }
}
