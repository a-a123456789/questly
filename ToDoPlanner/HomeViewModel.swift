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
        DayPart.sheetParts
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

    private let taskStore: TaskStore
    private let calendarClient: CalendarClient
    private var hasLoaded = false

    init(
        selectedDate: Date = .now,
        newTaskViewModel: NewTaskViewModel? = nil,
        taskStore: TaskStore,
        calendarClient: CalendarClient
    ) {
        self.selectedDate = selectedDate
        self.newTaskViewModel = newTaskViewModel
        self.taskStore = taskStore
        self.calendarClient = calendarClient
    }

    convenience init(
        selectedDate: Date = .now,
        newTaskViewModel: NewTaskViewModel? = nil
    ) {
        self.init(
            selectedDate: selectedDate,
            newTaskViewModel: newTaskViewModel,
            taskStore: TaskStore(),
            calendarClient: CalendarClient()
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
        let start = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)
        ) ?? selectedDate
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }

            return HomeDayItem(
                date: date,
                weekdayText: date.formatted(.dateTime.weekday(.abbreviated)).uppercased(),
                dayText: date.formatted(.dateTime.day()),
                isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
            )
        }
    }

    var sections: [HomeSectionModel] {
        DayPart.plannerParts.map { part in
            let taskEntries = taskStore.tasks(for: selectedDate, dayPart: part).map {
                HomeSectionEntry.task(
                    HomeTaskRowModel(id: $0.id, title: $0.title, isDone: $0.isDone)
                )
            }
            let eventEntries = (calendarClient.eventsByDayPart[part] ?? []).prefix(2).map {
                HomeSectionEntry.event(
                    HomeEventRowModel(
                        id: $0.id,
                        title: $0.title,
                        timeText: eventTimeText(for: $0)
                    )
                )
            }

            return HomeSectionModel(
                part: part,
                title: part.title,
                timeRangeText: part.timeRangeText,
                iconURL: iconURL(for: part),
                entries: taskEntries + eventEntries
            )
        }
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        taskStore.seedIfNeeded(for: selectedDate)
        refreshCalendar(for: selectedDate)
        objectWillChange.send()
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        taskStore.seedIfNeeded(for: date)
        refreshCalendar(for: date)
    }

    func toggleDone(_ id: UUID) {
        taskStore.toggleDone(id)
        objectWillChange.send()
    }

    func addTask(_ draft: NewTaskDraft) {
        taskStore.addTask(
            title: draft.title,
            details: draft.details,
            date: selectedDate,
            dayPart: draft.dayPart,
            priority: draft.priority,
            rewardPoints: draft.rewardPoints
        )
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
            await calendarClient.refresh(for: date)
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
        URL(string: "https://www.figma.com/api/mcp/asset/b7f43aeb-86da-4f6d-abc2-889bf25e0d22")!
    case .midday:
        URL(string: "https://www.figma.com/api/mcp/asset/ea240abf-4157-4a2e-ada7-8e8aaf60c689")!
    case .evening:
        URL(string: "https://www.figma.com/api/mcp/asset/c14557a5-283a-4e78-8771-4ae7f9c154f5")!
    case .inbox:
        URL(string: "https://www.figma.com/api/mcp/asset/90131a9e-37e6-4d41-a19c-ec59ab7c4047")!
    }
}
