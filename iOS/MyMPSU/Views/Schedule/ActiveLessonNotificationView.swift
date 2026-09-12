import SwiftUI

struct ActiveLessonNotificationView: View {
    let lesson: ScheduleItem
    let progress: Double

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.fill")
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(lesson.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(lesson.time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
            ProgressView(value: progress)
                .frame(width: 72)
        }
        .padding(.horizontal, 12)
        .frame(height: 54)
        .mympsuAdaptiveGlassCard(cornerRadius: 18)
    }
}
