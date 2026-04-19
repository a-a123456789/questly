import Foundation
import SwiftUI

enum HomeTaskCompletionFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case active
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "All"
        case .active:
            "Active"
        case .completed:
            "Completed"
        }
    }
}

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
    let details: String?
    let isDone: Bool
    let dueDate: Date?
    let dayPart: DayPart
    let priority: TaskPriority
    let rewardPoints: TaskRewardPoints
    let reminderDate: Date?
    let recurrence: TaskRecurrence
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

struct HomeInsightsModel: Hashable {
    let completedToday: Int
    let completedThisWeek: Int
    let activeCount: Int
    let overdueCount: Int
    let dailyStreak: Int

    static let empty = HomeInsightsModel(
        completedToday: 0,
        completedThisWeek: 0,
        activeCount: 0,
        overdueCount: 0,
        dailyStreak: 0
    )
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
    @Published var isReminderEnabled: Bool
    @Published var reminderDate: Date
    @Published var selectedRecurrence: TaskRecurrence = .none

    init(defaultDayPart: DayPart, date: Date, onAdd: @escaping (NewTaskDraft) -> Void) {
        self.selectedWhen = defaultDayPart
        self.date = date
        self.onAdd = onAdd
        if let defaultReminder = Self.defaultReminderDate(for: defaultDayPart, on: date) {
            self.isReminderEnabled = true
            self.reminderDate = defaultReminder
        } else {
            self.isReminderEnabled = false
            self.reminderDate = date
        }
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

    var recurrenceOptions: [TaskRecurrence] {
        TaskRecurrence.allCases
    }

    func makeDraft() -> NewTaskDraft? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }

        return NewTaskDraft(
            title: trimmedTitle,
            details: description.trimmingCharacters(in: .whitespacesAndNewlines),
            dayPart: selectedWhen,
            priority: selectedPriority,
            rewardPoints: selectedPoints,
            reminderDate: isReminderEnabled ? reminderDate : nil,
            recurrence: selectedRecurrence
        )
    }

    func selectWhen(_ newPart: DayPart) {
        let oldPart = selectedWhen
        selectedWhen = newPart

        let wasUsingOldDefault = {
            guard let oldDefault = Self.defaultReminderDate(for: oldPart, on: date) else { return false }
            return Calendar.current.isDate(reminderDate, equalTo: oldDefault, toGranularity: .minute)
        }()

        if !isReminderEnabled, let defaultReminder = Self.defaultReminderDate(for: newPart, on: date) {
            reminderDate = defaultReminder
            return
        }

        if isReminderEnabled, wasUsingOldDefault {
            if let defaultReminder = Self.defaultReminderDate(for: newPart, on: date) {
                reminderDate = defaultReminder
            } else {
                isReminderEnabled = false
            }
        }
    }

    func setReminderEnabled(_ enabled: Bool) {
        isReminderEnabled = enabled
        guard enabled else { return }
        if let defaultReminder = Self.defaultReminderDate(for: selectedWhen, on: date) {
            reminderDate = defaultReminder
        }
    }

    private static func defaultReminderDate(for part: DayPart, on date: Date) -> Date? {
        guard let hour = part.defaultReminderHour else { return nil }
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date)
    }

    @discardableResult
    func addTask() -> Bool {
        guard let draft = makeDraft() else { return false }
        onAdd(draft)
        return true
    }
}

@MainActor
final class EditTaskViewModel: ObservableObject, Identifiable {
    let id = UUID()
    let taskID: UUID
    private let onSave: (UUID, EditTaskDraft) -> Void

    @Published var title: String
    @Published var description: String
    @Published var selectedWhen: DayPart
    @Published var selectedPriority: TaskPriority
    @Published var selectedPoints: TaskRewardPoints
    @Published var isReminderEnabled: Bool
    @Published var reminderDate: Date
    @Published var selectedRecurrence: TaskRecurrence

    init(task: HomeTaskRowModel, onSave: @escaping (UUID, EditTaskDraft) -> Void) {
        self.taskID = task.id
        self.title = task.title
        self.description = task.details ?? ""
        self.selectedWhen = task.dayPart
        self.selectedPriority = task.priority
        self.selectedPoints = task.rewardPoints
        self.isReminderEnabled = task.reminderDate != nil
        let anchorDate = task.dueDate ?? Date()
        self.reminderDate = task.reminderDate ?? task.dayPart.defaultReminderHour.flatMap {
            Calendar.current.date(bySettingHour: $0, minute: 0, second: 0, of: anchorDate)
        } ?? Date()
        self.selectedRecurrence = task.recurrence
        self.onSave = onSave
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

    var recurrenceOptions: [TaskRecurrence] {
        TaskRecurrence.allCases
    }

    func makeDraft() -> EditTaskDraft? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }

        return EditTaskDraft(
            title: trimmedTitle,
            details: description.trimmingCharacters(in: .whitespacesAndNewlines),
            dayPart: selectedWhen,
            priority: selectedPriority,
            rewardPoints: selectedPoints,
            reminderDate: isReminderEnabled ? reminderDate : nil,
            recurrence: selectedRecurrence
        )
    }

    func selectWhen(_ newPart: DayPart) {
        let oldPart = selectedWhen
        selectedWhen = newPart

        let wasUsingOldDefault = {
            guard let oldDefault = Self.defaultReminderDate(for: oldPart, anchoredTo: reminderDate) else { return false }
            return Calendar.current.isDate(reminderDate, equalTo: oldDefault, toGranularity: .minute)
        }()

        if !isReminderEnabled, let defaultReminder = Self.defaultReminderDate(for: newPart, anchoredTo: reminderDate) {
            reminderDate = defaultReminder
            return
        }

        if isReminderEnabled, wasUsingOldDefault {
            if let defaultReminder = Self.defaultReminderDate(for: newPart, anchoredTo: reminderDate) {
                reminderDate = defaultReminder
            } else {
                isReminderEnabled = false
            }
        }
    }

    func setReminderEnabled(_ enabled: Bool) {
        let wasEnabled = isReminderEnabled
        isReminderEnabled = enabled
        guard enabled, !wasEnabled else { return }
        if let defaultReminder = Self.defaultReminderDate(for: selectedWhen, anchoredTo: reminderDate) {
            reminderDate = defaultReminder
        }
    }

    private static func defaultReminderDate(for part: DayPart, anchoredTo date: Date) -> Date? {
        guard let hour = part.defaultReminderHour else { return nil }
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date)
    }

    @discardableResult
    func saveTask() -> Bool {
        guard let draft = makeDraft() else { return false }
        onSave(taskID, draft)
        return true
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var selectedDate: Date
    @Published var newTaskViewModel: NewTaskViewModel?
    @Published var editTaskViewModel: EditTaskViewModel?
    @Published var searchText: String = "" {
        didSet { refreshSectionsForDiscoveryState() }
    }
    @Published var completionFilter: HomeTaskCompletionFilter = .all {
        didSet { refreshSectionsForDiscoveryState() }
    }
    @Published var priorityFilter: TaskPriority? {
        didSet { refreshSectionsForDiscoveryState() }
    }
    @Published private(set) var sections: [HomeSectionModel] = []
    @Published private(set) var persistenceMessage: String?
    @Published private(set) var insights: HomeInsightsModel = .empty
    @Published private(set) var notificationAuthorizationStatus: NotificationAuthorizationState = .notDetermined

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

    var completionFilterOptions: [HomeTaskCompletionFilter] {
        HomeTaskCompletionFilter.allCases
    }

    var notificationPermissionStatusText: String {
        switch notificationAuthorizationStatus {
        case .authorized:
            "Allowed"
        case .notDetermined:
            "Not requested"
        case .denied:
            "Denied"
        }
    }

    var notificationPermissionDescription: String {
        switch notificationAuthorizationStatus {
        case .authorized:
            "Task reminders are enabled for Questly on this device."
        case .notDetermined:
            "Turn on reminders while creating or editing a task and iOS will prompt for permission."
        case .denied:
            "Reminders are currently blocked. Open iOS Settings and allow notifications for Questly."
        }
    }

    var shouldShowNotificationSettingsButton: Bool {
        notificationAuthorizationStatus == .denied
    }

    var priorityFilterTitle: String {
        priorityFilter?.title ?? "All priorities"
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        taskRepository.seedIfNeeded(for: selectedDate)
        reloadSections(animated: false)
        syncPersistenceState()
        refreshNotificationAuthorizationStatus()
        refreshCalendar(for: selectedDate)
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        taskRepository.seedIfNeeded(for: date)
        reloadSections(animated: false)
        syncPersistenceState()
        refreshNotificationAuthorizationStatus()
        refreshCalendar(for: date)
    }

    func toggleDone(_ id: UUID) {
        taskRepository.toggleDone(id)
        reloadSections()
        syncPersistenceState()
        refreshNotificationAuthorizationStatus()
    }

    func addTask(_ draft: NewTaskDraft) {
        taskRepository.addTask(draft, for: selectedDate)
        reloadSections()
        syncPersistenceState()
        refreshNotificationAuthorizationStatus()
    }

    func editTask(_ id: UUID, with draft: EditTaskDraft) {
        taskRepository.updateTask(id, with: draft, for: selectedDate)
        reloadSections()
        syncPersistenceState()
        refreshNotificationAuthorizationStatus()
    }

    func deleteTask(_ id: UUID) {
        taskRepository.deleteTask(id)
        reloadSections()
        syncPersistenceState()
        refreshNotificationAuthorizationStatus()
    }

    func resetLocalData() {
        taskRepository.resetLocalData()
        reloadSections()
        syncPersistenceState()
        refreshNotificationAuthorizationStatus()
    }

    func moveTask(_ id: UUID, to dayPart: DayPart) {
        taskRepository.moveTask(id, to: dayPart, for: selectedDate)
        reloadSections()
        syncPersistenceState()
        refreshNotificationAuthorizationStatus()
    }

    func refreshNotificationAuthorizationStatus() {
        Task { [weak self] in
            guard let self else { return }
            self.notificationAuthorizationStatus = await self.taskRepository.notificationAuthorizationStatus()
        }
    }

    func presentNewTask(for part: DayPart) {
        newTaskViewModel = NewTaskViewModel(defaultDayPart: part, date: selectedDate) { [weak self] draft in
            self?.addTask(draft)
            self?.dismissNewTask()
        }
    }

    func presentEditTask(_ task: HomeTaskRowModel) {
        editTaskViewModel = EditTaskViewModel(task: task) { [weak self] id, draft in
            self?.editTask(id, with: draft)
            self?.dismissEditTask()
        }
    }

    private func dismissNewTask() {
        newTaskViewModel = nil
    }

    private func dismissEditTask() {
        editTaskViewModel = nil
    }

    private func refreshCalendar(for date: Date) {
        guard !isRunningInPreviews else { return }
        Task {
            await calendarRepository.refresh(for: date)
            reloadSections(animated: false)
        }
    }

    private func reloadSections(animated: Bool = true) {
        let newSections = getPlannerSections.execute(date: selectedDate).map { section in
            let allTaskRows = section.tasks.map {
                HomeTaskRowModel(
                    id: $0.id,
                    title: $0.title,
                    details: $0.details,
                    isDone: $0.isDone,
                    dueDate: $0.dueDate,
                    dayPart: $0.dayPart,
                    priority: $0.priority,
                    rewardPoints: $0.rewardPoints,
                    reminderDate: $0.reminderDate,
                    recurrence: $0.recurrence
                )
            }
            let taskEntries = allTaskRows
                .filter(matchesFilters)
                .map { HomeSectionEntry.task($0) }
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

        if animated {
            withAnimation(.easeInOut(duration: 0.2)) {
                sections = newSections
            }
        } else {
            sections = newSections
        }
        refreshInsights()
    }

    private func refreshSectionsForDiscoveryState() {
        guard hasLoaded else { return }
        reloadSections(animated: false)
    }

    private func matchesFilters(_ task: HomeTaskRowModel) -> Bool {
        switch completionFilter {
        case .all:
            break
        case .active:
            guard !task.isDone else { return false }
        case .completed:
            guard task.isDone else { return false }
        }

        if let priorityFilter, task.priority != priorityFilter {
            return false
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        if task.title.localizedCaseInsensitiveContains(query) {
            return true
        }

        if let details = task.details, details.localizedCaseInsensitiveContains(query) {
            return true
        }

        return false
    }

    private func refreshInsights() {
        let tasks = taskRepository.allTasks()
        let calendar = Calendar.current
        let now = Date()

        let completedTimestamps = tasks.compactMap(\.completedAt)
        let completedToday = completedTimestamps.filter { calendar.isDateInToday($0) }.count

        let completedThisWeek: Int = {
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
            return completedTimestamps.filter { interval.contains($0) }.count
        }()

        let activeCount = tasks.filter { !$0.isDone }.count
        let overdueCount = tasks.filter {
            guard !$0.isDone else { return false }
            guard let dueDate = $0.dueDate else { return false }
            return dueDate < now
        }.count

        insights = HomeInsightsModel(
            completedToday: completedToday,
            completedThisWeek: completedThisWeek,
            activeCount: activeCount,
            overdueCount: overdueCount,
            dailyStreak: calculateDailyStreak(completionDates: completedTimestamps, now: now, calendar: calendar)
        )
    }

    private func calculateDailyStreak(completionDates: [Date], now: Date, calendar: Calendar) -> Int {
        let completionDays = Set(completionDates.map { calendar.startOfDay(for: $0) })
        var streak = 0
        var currentDay = calendar.startOfDay(for: now)

        while completionDays.contains(currentDay) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
            currentDay = previousDay
        }

        return streak
    }

    private func syncPersistenceState() {
        persistenceMessage = taskRepository.lastPersistenceErrorMessage
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
