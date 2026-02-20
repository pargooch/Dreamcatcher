import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showingPermissionAlert = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: ComicTheme.Dimensions.gutterWidth) {
                // Permission section
                ComicPanelCard(titleBanner: L("Permission"), bannerColor: ComicTheme.Colors.emeraldGreen) {
                    if notificationManager.isAuthorized {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3.weight(.bold))
                                .foregroundColor(ComicTheme.Colors.emeraldGreen)
                            Text(L("Notifications Enabled"))
                                .font(ComicTheme.Typography.comicButton(14))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    } else {
                        VStack(spacing: 12) {
                            Button {
                                Task {
                                    let granted = await notificationManager.requestAuthorization()
                                    if !granted {
                                        showingPermissionAlert = true
                                    }
                                }
                            } label: {
                                Label(L("Enable Notifications"), systemImage: "bell.badge")
                            }
                            .buttonStyle(.comicPrimary(color: ComicTheme.Colors.emeraldGreen))

                            Text(L("Allow notifications to receive reminders and follow-ups."))
                                .font(ComicTheme.Typography.speechBubble(12))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                // Notification Types section
                ComicPanelCard(titleBanner: L("Notification Types"), bannerColor: ComicTheme.Colors.boldBlue) {
                    VStack(spacing: 14) {
                        Text(L("Configure each notification type independently with its own schedule."))
                            .font(ComicTheme.Typography.speechBubble(12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(NotificationCategory.allCases) { category in
                            NotificationTemplateRow(category: category)

                            if category != NotificationCategory.allCases.last {
                                Rectangle()
                                    .fill(ComicTheme.Semantic.panelBorder(colorScheme).opacity(0.15))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, 4)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .halftoneBackground()
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: category.icon)
                    .font(.body.weight(.bold))
                    .foregroundColor(ComicTheme.Colors.boldBlue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(ComicTheme.Typography.comicButton(14))
                    Text(category.description)
                        .font(ComicTheme.Typography.speechBubble(12))
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
                .tint(ComicTheme.Colors.emeraldGreen)
            }

            if isEnabled, let schedule = settings?.schedule {
                Button {
                    showingScheduleSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.caption.weight(.bold))
                        Text(scheduleDescription(schedule))
                            .font(ComicTheme.Typography.speechBubble(12))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(ComicTheme.Semantic.cardSurface(colorScheme))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(ComicTheme.Semantic.panelBorder(colorScheme).opacity(0.2), lineWidth: 1)
                    )
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
    @Environment(\.colorScheme) private var colorScheme

    @State private var frequency: NotificationFrequency = .daily
    @State private var time: Date = Date()
    @State private var selectedDays: Set<Int> = []
    @State private var weeklyDay: Int = 2

    private var dayNames: [String] {
        [L("Sun"), L("Mon"), L("Tue"), L("Wed"), L("Thu"), L("Fri"), L("Sat")]
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: ComicTheme.Dimensions.gutterWidth) {
                    // Frequency
                    ComicPanelCard(titleBanner: L("When to Notify"), bannerColor: ComicTheme.Colors.boldBlue) {
                        Picker(L("Frequency"), selection: $frequency) {
                            ForEach(NotificationFrequency.allCases) { freq in
                                Text(freq.displayName).tag(freq)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Time
                    ComicPanelCard(titleBanner: L("Time of Day"), bannerColor: ComicTheme.Colors.goldenYellow) {
                        DatePicker(L("Time"), selection: $time, displayedComponents: .hourAndMinute)
                            .font(ComicTheme.Typography.comicButton(14))
                    }

                    // Weekly day picker
                    if frequency == .weekly {
                        ComicPanelCard(titleBanner: L("Day of Week"), bannerColor: ComicTheme.Colors.deepPurple) {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                                ForEach(1...7, id: \.self) { day in
                                    DayToggleButton(
                                        day: day,
                                        dayName: dayNames[day - 1],
                                        isSelected: weeklyDay == day
                                    ) {
                                        weeklyDay = day
                                    }
                                }
                            }
                        }
                    }

                    // Custom days picker
                    if frequency == .custom {
                        ComicPanelCard(titleBanner: L("Select Days"), bannerColor: ComicTheme.Colors.deepPurple) {
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
                        }
                    }

                    // Preview
                    ComicPanelCard(titleBanner: L("Preview"), bannerColor: ComicTheme.Colors.emeraldGreen) {
                        HStack(spacing: 10) {
                            Image(systemName: "bell.fill")
                                .font(.body.weight(.bold))
                                .foregroundColor(ComicTheme.Colors.emeraldGreen)
                                .frame(width: 24)
                            Text(previewDescription)
                                .font(ComicTheme.Typography.speechBubble(13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
            .halftoneBackground()
            .navigationTitle(category.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(ComicTheme.Colors.crimsonRed)
                    .fontWeight(.bold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Save")) {
                        saveSchedule()
                        dismiss()
                    }
                    .foregroundStyle(ComicTheme.Colors.emeraldGreen)
                    .fontWeight(.bold)
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
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? ComicTheme.Colors.deepPurple : ComicTheme.Semantic.cardSurface(colorScheme))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                                ? ComicTheme.Colors.deepPurple.opacity(0.5)
                                : ComicTheme.Semantic.panelBorder(colorScheme).opacity(0.2),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
