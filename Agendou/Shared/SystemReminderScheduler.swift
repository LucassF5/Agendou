import AgendouCore
import AgendouStore
import Foundation
import UserNotifications

/// Schedules the shift reminders as local notifications: the system keeps and fires them, no server involved.
struct SystemReminderScheduler: ReminderScheduling {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func replaceAll(with reminders: [PlannedReminder]) async {
        center.removeAllPendingNotificationRequests()
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Plantão hoje")
            content.body = reminder.shifts
                .map { "\($0.categoryName) · \(Formatting.timeRange(startsAt: $0.startsAt, endsAt: $0.endsAt))" }
                .joined(separator: "\n")
            content.sound = .default

            // Fired in the workplace time zone, like everything else in the app, not the device's.
            var components = CivilCalendar.calendar.dateComponents(
                [.year, .month, .day, .hour, .minute], from: Date(epochSeconds: reminder.fireAt))
            components.timeZone = CivilCalendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(
                UNNotificationRequest(
                    identifier: "shift-reminder-\(reminder.day.string)", content: content, trigger: trigger))
        }
    }
}

/// Stands in for the system in UI tests: grants permission at once and schedules nothing.
struct UITestReminderScheduler: ReminderScheduling {
    func requestAuthorization() async -> Bool { true }
    func replaceAll(with reminders: [PlannedReminder]) async {}
}
