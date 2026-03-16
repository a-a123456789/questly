import Foundation
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var selectedDate: Date
    @Published var showingNewTask: DayPart?

    private let taskStore: TaskStore
    private let calendarClient: CalendarClient
    private var hasLoaded = false

    init(
        selectedDate: Date = .now,
        showingNewTask: DayPart? = nil,
        taskStore: TaskStore = TaskStore(),
        calendarClient: CalendarClient = CalendarClient()
    ) {
        self.selectedDate = selectedDate
        self.showingNewTask = showingNewTask
        self.taskStore = taskStore
        self.calendarClient = calendarClient
    }

    var weekdayText: String {
        selectedDate.formatted(.dateTime.weekday(.wide))
    }

    var fullDateText: String {
        selectedDate.formatted(.dateTime.month(.wide).day().year())
    }

    var weekDates: [Date] {
        let calendar = Calendar.current
        let start = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)
        ) ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
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

    func tasks(for part: DayPart) -> [TodoItem] {
        taskStore.tasks(for: selectedDate, dayPart: part)
    }

    func events(for part: DayPart) -> [PlannerEvent] {
        calendarClient.eventsByDayPart[part] ?? []
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
        showingNewTask = part
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
}
