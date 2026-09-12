import SwiftUI

struct CalendarDatePicker: View {
    @Binding var selectedDate: Date
    @State private var isPressFeedbackVisible = false
    @State private var isCustomCalendarPresented = false
    @State private var customCalendarDisplayedMonth = Date()

    var showsChrome = true
    var showsCalendarIcon = false
    var pickerPresentationOffset: CGSize = .zero
    var alignsPickerPresentationToTrailingEdge = false
    var onAlignedCalendarTap: (() -> Void)?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 7) {
                if showsCalendarIcon {
                    Image(systemName: "calendar")
                        .font(.subheadline.weight(.semibold))
                }

                Text(formattedDate)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.primary)
            .opacity(isPressFeedbackVisible ? 0.55 : 1)
            .padding(showsChrome ? 8 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(showsChrome ? Color.mympsuHeaderCapsuleFill : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if alignsPickerPresentationToTrailingEdge {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        flashPressFeedback()
                        onAlignedCalendarTap?()
                    }
            } else {
#if os(macOS)
                Button {
                    customCalendarDisplayedMonth = selectedDate
                    flashPressFeedback()
                    isCustomCalendarPresented.toggle()
                } label: {
                    Color.clear
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isCustomCalendarPresented, arrowEdge: .bottom) {
                    AlignedCalendarOverlay(
                        selectedDate: $selectedDate,
                        displayedMonth: $customCalendarDisplayedMonth
                    ) {
                        isCustomCalendarPresented = false
                    }
                    .frame(width: 318)
                    .padding(8)
                }
#else
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .opacity(0.02)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
#endif
            }
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    flashPressFeedback()
                }
        )
        .accessibilityLabel(formattedDate)
    }

    private func flashPressFeedback() {
        withAnimation(.easeOut(duration: 0.05)) {
            isPressFeedbackVisible = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.easeOut(duration: 0.14)) {
                isPressFeedbackVisible = false
            }
        }
    }

    private var formattedDate: String {
        let value = Self.dateFormatter.string(from: selectedDate)
        guard let first = value.first else { return value }
        return first.uppercased() + value.dropFirst()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = .current
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter
    }()
}

struct AlignedCalendarOverlay: View {
    @Binding var selectedDate: Date
    @Binding var displayedMonth: Date

    var onSelect: () -> Void
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_RU")
        return calendar
    }()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdays = ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Text(monthTitle)
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(monthButtonBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(monthButtonBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                        .frame(height: 20)
                }

                ForEach(calendarDays.indices, id: \.self) { index in
                    if let date = calendarDays[index] {
                        Button {
                            selectedDate = date
                            onSelect()
                        } label: {
                            ZStack(alignment: .bottom) {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.body.weight(isSelected(date) ? .bold : .medium))
                                    .foregroundColor(isSelected(date) ? .white : .primary)
                                    .frame(width: 36, height: 36)
                                    .background(selectedDayBackground(isSelected: isSelected(date)))

                                if calendar.isDateInToday(date) && !isSelected(date) {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 5, height: 5)
                                        .offset(y: 3)
                                }
                            }
                            .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(width: 36, height: 36)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(calendarBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(calendarStroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
    }

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    @ViewBuilder
    private var calendarBackground: some View {
        if activeTheme.usesCloudSurface {
            switch activeTheme.backgroundStyle {
            case .dreamySkyDay:
                Color(red: 0.96, green: 0.98, blue: 1.00)
            case .dreamySkyNight:
                Color(red: 0.12, green: 0.15, blue: 0.26)
            default:
                activeTheme.cloudSurfaceFill.opacity(1)
            }
        } else {
#if os(macOS)
            Color(NSColor.windowBackgroundColor)
#else
            Color(UIColor.secondarySystemBackground)
#endif
        }
    }

    private var calendarStroke: Color {
        activeTheme.usesCloudSurface
        ? activeTheme.cloudSurfaceStroke
        : Color.primary.opacity(0.10)
    }

    @ViewBuilder
    private var monthButtonBackground: some View {
        if activeTheme.usesCloudSurface {
            activeTheme.cloudSurfaceFill.opacity(0.65)
        } else {
            Color.primary.opacity(0.07)
        }
    }

    @ViewBuilder
    private func selectedDayBackground(isSelected: Bool) -> some View {
        if isSelected {
            Circle().fill(Color.accentColor)
        } else {
            Color.clear
        }
    }

    private var calendarDays: [Date?] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
            let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth)
        else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingEmptyDays = (firstWeekday + 5) % 7
        let days = dayRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }

        return Array(repeating: nil, count: leadingEmptyDays) + days
    }

    private var monthTitle: String {
        let value = Self.monthFormatter.string(from: displayedMonth)
        guard let first = value.first else { return value }
        return first.uppercased() + value.dropFirst()
    }

    private func moveMonth(by value: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = nextMonth
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy 'г.'"
        return formatter
    }()
}
