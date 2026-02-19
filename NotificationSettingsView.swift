import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showingPermissionAlert = false

    var body: some View {
        List {
            // Authorization Section
            Section {
                if notificationManager.isAuthorized {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(L("Notifications Enabled"))
                        Spacer()
                    }
                } else {
                    Button {
                        Task {
                            let granted = await notificationManager.requestAuthorization()
                            if !granted {
                                showingPermissionAlert = true
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(.orange)
                            Text(L("Enable Notifications"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text(L("Permission"))
            } footer: {
                if !notificationManager.isAuthorized {
                    Text(L("Allow notifications to receive reminders and follow-ups."))
                }
            }

            // Notification Templates Section
            Section {
                ForEach(NotificationCategory.allCases) { category in
                    NotificationTemplateRow(category: category)
                }
            } header: {
                Text(L("Notification Types"))
            } footer: {
                Text(L("Configure each notification type independently with its own schedule."))
            }
        }
        .navigationTitle(L("Notifications"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(L("Permission Required"), isPresented: $showingPermissionAlert) {
            Button(L("Open Settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(L("Cancel"), role: .cancel) { }
        } message: {
            Text(L("Please enable notifications in Settings to receive reminders."))
        }
    }
}

struct NotificationTemplateRow: View {
    let category: NotificationCategory
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showingScheduleSheet = false
    @Environment(\.colorScheme) private var colorScheme

    private var settings: NotificationSettings? {
        notificationManager.getSettings(for: category)
    }

    private var isEnabled: Bool {
        settings?.isEnabled ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(ComicTheme.Palette.heroBlue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.headline)
                    Text(category.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        notificationManager.updateSettings(for: category, isEnabled: newValue)
                    }
                ))
                .labelsHidden()
            }

            if isEnabled, let schedule = settings?.schedule {
                Button {
                    showingScheduleSheet = true
                } label: {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(scheduleDescription(schedule))
                            .font(.caption)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(ComicTheme.Semantic.cardSurface(colorScheme))
                    .cornerRadius(ComicTheme.Dimensions.badgeCornerRadius)
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingScheduleSheet) {
            ScheduleEditorView(category: category)
        }
    }

    private func scheduleDescription(_ schedule: NotificationSchedule) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let timeString = timeFormatter.string(from: schedule.time)
        let frequencyString = schedule.frequency.displayName

        return "\(frequencyString) at \(timeString)"
    }
}

struct ScheduleEditorView: View {
    let category: NotificationCategory
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var frequency: NotificationFrequency = .daily
    @State private var time: Date = Date()
    @State private var selectedDays: Set<Int> = []
    @State private var weeklyDay: Int = 2

    private var dayNames: [String] {
        [L("Sun"), L("Mon"), L("Tue"), L("Wed"), L("Thu"), L("Fri"), L("Sat")]
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker(L("Frequency"), selection: $frequency) {
                        ForEach(NotificationFrequency.allCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                } header: {
                    Text(L("When to Notify"))
                }

                Section {
                    DatePicker(L("Time"), selection: $time, displayedComponents: .hourAndMinute)
                } header: {
                    Text(L("Time of Day"))
                }

                if frequency == .weekly {
                    Section {
                        Picker(L("Day"), selection: $weeklyDay) {
                            ForEach(1...7, id: \.self) { day in
                                Text(dayNames[day - 1]).tag(day)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text(L("Day of Week"))
                    }
                }

                if frequency == .custom {
                    Section {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                            ForEach(1...7, id: \.self) { day in
                                DayToggleButton(
                                    day: day,
                                    dayName: dayNames[day - 1],
                                    isSelected: selectedDays.contains(day)
                                ) {
                                    if selectedDays.contains(day) {
                                        selectedDays.remove(day)
                                    } else {
                                        selectedDays.insert(day)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(L("Select Days"))
                    }
                }

                Section {
                    Text(previewDescription)
                        .font(.callout)
                        .foregroundColor(.secondary)
                } header: {
                    Text(L("Preview"))
                }
            }
            .navigationTitle(category.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Save")) {
                        saveSchedule()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentSettings()
            }
        }
    }

    private var previewDescription: String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: time)

        switch frequency {
        case .daily:
            return L("You'll receive a notification every day at %@.", timeString)
        case .weekdays:
            return L("You'll receive notifications Monday through Friday at %@.", timeString)
        case .weekends:
            return L("You'll receive notifications on Saturday and Sunday at %@.", timeString)
        case .weekly:
            return L("You'll receive a notification every %@ at %@.", dayNames[weeklyDay - 1], timeString)
        case .custom:
            if selectedDays.isEmpty {
                return L("Select at least one day to receive notifications.")
            }
            let dayList = selectedDays.sorted().map { dayNames[$0 - 1] }.joined(separator: ", ")
            return L("You'll receive notifications on %@ at %@.", dayList, timeString)
        }
    }

    private func loadCurrentSettings() {
        if let settings = notificationManager.getSettings(for: category) {
            frequency = settings.schedule.frequency
            time = settings.schedule.time
            selectedDays = settings.schedule.selectedDays
            weeklyDay = settings.schedule.weeklyDay
        }
    }

    private func saveSchedule() {
        let schedule = NotificationSchedule(
            frequency: frequency,
            time: time,
            selectedDays: selectedDays,
            weeklyDay: weeklyDay
        )
        notificationManager.updateSettings(for: category, schedule: schedule)
    }
}

struct DayToggleButton: View {
    let day: Int
    let dayName: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(dayName)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? ComicTheme.Palette.heroBlue : ComicTheme.Semantic.cardSurface(colorScheme))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(ComicTheme.Dimensions.badgeCornerRadius)
        }
        .buttonStyle(.plain)
    }
}
