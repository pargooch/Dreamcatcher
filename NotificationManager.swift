import Foundation
import UserNotifications
import Combine

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false
    @Published var templates: [NotificationTemplate] = NotificationTemplate.defaults
    @Published var settings: [NotificationSettings] = []
    @Published var dreamNotifications: [DreamNotification] = []

    private let notificationCenter = UNUserNotificationCenter.current()
    private let settingsKey = "notification_settings"
    private let dreamNotificationsKey = "dream_notifications"

    private init() {
        loadSettings()
        loadDreamNotifications()
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
            }
            if granted {
                await rescheduleAllNotifications()
            }
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Settings Management

    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode([NotificationSettings].self, from: data) {
            settings = decoded
        } else {
            // Initialize with default settings for each template
            settings = templates.map { NotificationSettings(template: $0, isEnabled: false) }
            saveSettings()
        }
    }

    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }

    func updateSettings(for category: NotificationCategory, isEnabled: Bool? = nil, schedule: NotificationSchedule? = nil) {
        if let index = settings.firstIndex(where: { $0.category == category }) {
            if let enabled = isEnabled {
                settings[index].isEnabled = enabled
            }
            if let newSchedule = schedule {
                settings[index].schedule = newSchedule
            }
            saveSettings()

            Task {
                await rescheduleNotifications(for: category)
            }
        }
    }

    func getSettings(for category: NotificationCategory) -> NotificationSettings? {
        settings.first { $0.category == category }
    }

    // MARK: - Dream Notifications

    func loadDreamNotifications() {
        if let data = UserDefaults.standard.data(forKey: dreamNotificationsKey),
           let decoded = try? JSONDecoder().decode([DreamNotification].self, from: data) {
            dreamNotifications = decoded
        }
    }

    func saveDreamNotifications() {
        if let encoded = try? JSONEncoder().encode(dreamNotifications) {
            UserDefaults.standard.set(encoded, forKey: dreamNotificationsKey)
        }
    }

    func scheduleDreamNotification(for dream: Dream, afterHours: Int = 24) {
        let scheduledDate = Date().addingTimeInterval(TimeInterval(afterHours * 3600))

        let notification = DreamNotification(
            dreamId: dream.id,
            scheduledDate: scheduledDate,
            type: dream.rewrittenText != nil ? .nightmareFollowUp : .dreamReflection
        )

        dreamNotifications.append(notification)
        saveDreamNotifications()

        Task {
            await scheduleLocalNotification(for: notification, dream: dream)
        }
    }

    func cancelDreamNotification(for dreamId: UUID) {
        dreamNotifications.removeAll { $0.dreamId == dreamId }
        saveDreamNotifications()
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["dream_\(dreamId.uuidString)"])
    }

    // MARK: - Scheduling

    func rescheduleAllNotifications() async {
        // Cancel all existing notifications
        notificationCenter.removeAllPendingNotificationRequests()

        // Reschedule each enabled category
        for setting in settings where setting.isEnabled {
            await scheduleNotifications(for: setting)
        }

        // Reschedule dream-specific notifications
        for notification in dreamNotifications where notification.isEnabled {
            // We need the dream to get context, but we'll use generic message if not available
            await scheduleGenericDreamNotification(notification)
        }
    }

    func rescheduleNotifications(for category: NotificationCategory) async {
        // Cancel existing notifications for this category
        let identifierPrefix = category.rawValue
        let pending = await notificationCenter.pendingNotificationRequests()
        let toRemove = pending.filter { $0.identifier.hasPrefix(identifierPrefix) }.map { $0.identifier }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: toRemove)

        // Reschedule if enabled
        if let setting = settings.first(where: { $0.category == category }), setting.isEnabled {
            await scheduleNotifications(for: setting)
        }
    }

    private func scheduleNotifications(for setting: NotificationSettings) async {
        guard let template = templates.first(where: { $0.category == setting.category }) else { return }

        let schedule = setting.schedule
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: schedule.time)

        for day in schedule.effectiveDays {
            var dateComponents = DateComponents()
            dateComponents.weekday = day
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute

            let content = UNMutableNotificationContent()
            content.title = template.randomTitle()
            content.body = template.randomBody()
            content.sound = .default
            content.categoryIdentifier = setting.category.rawValue

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let identifier = "\(setting.category.rawValue)_day\(day)"

            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await notificationCenter.add(request)
            } catch {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    private func scheduleLocalNotification(for notification: DreamNotification, dream: Dream) async {
        guard let template = templates.first(where: { $0.category == notification.notificationType }) else { return }

        let content = UNMutableNotificationContent()
        content.title = template.randomTitle()

        // Personalize body with dream context
        if dream.rewrittenText != nil {
            content.body = "How are you feeling about the dream you rewrote? Take a moment to read your peaceful version."
        } else {
            content.body = template.randomBody()
        }

        content.sound = .default
        content.categoryIdentifier = notification.notificationType.rawValue
        content.userInfo = ["dreamId": dream.id.uuidString]

        let triggerDate = notification.scheduledDate
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = "dream_\(dream.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule dream notification: \(error)")
        }
    }

    private func scheduleGenericDreamNotification(_ notification: DreamNotification) async {
        guard let template = templates.first(where: { $0.category == notification.notificationType }) else { return }

        let content = UNMutableNotificationContent()
        content.title = template.randomTitle()
        content.body = template.randomBody()
        content.sound = .default
        content.categoryIdentifier = notification.notificationType.rawValue
        content.userInfo = ["dreamId": notification.dreamId.uuidString]

        let triggerDate = notification.scheduledDate
        guard triggerDate > Date() else { return } // Don't schedule past notifications

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = "dream_\(notification.dreamId.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule dream notification: \(error)")
        }
    }

    // MARK: - Utility

    func getPendingNotificationCount() async -> Int {
        let pending = await notificationCenter.pendingNotificationRequests()
        return pending.count
    }
}
