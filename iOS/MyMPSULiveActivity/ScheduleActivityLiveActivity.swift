import ActivityKit
import WidgetKit
import SwiftUI

@available(iOSApplicationExtension 16.1, *)
struct ScheduleActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScheduleActivityAttributes.self) { context in
            lockScreenLayout(context: context)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    islandCurrentColumn(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    islandNextColumn(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    progressRing(context: context)
                        .frame(width: 28, height: 28)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 5) {
                        HStack(spacing: 8) {
                            Text(context.state.startTime, style: .time)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 40, alignment: .leading)
                            lessonProgressView(context: context)
                            Text(context.state.endTime, style: .time)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 40, alignment: .trailing)
                        }

                        Text(context.state.endTime, style: .timer)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            } compactLeading: {
                progressRing(context: context)
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                Text("\(context.state.endTime, style: .timer)")
                    .font(.caption2.monospacedDigit())
            } minimal: {
                progressRing(context: context)
                    .frame(width: 18, height: 18)
            }
            .widgetURL(URL(string: "mympsu://schedule"))
            .keylineTint(activityTint(for: context))
        }
    }

    private func lockScreenLayout(context: ActivityViewContext<ScheduleActivityAttributes>) -> some View {
        let isBreak = context.state.lessonTitle == "Перерыв"
        let nextDetails = splitNextSubtitle(context.state.nextSubtitle)

        return VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 22) {
                lessonColumn(
                    caption: isBreak ? "" : "Текущая",
                    title: context.state.lessonTitle,
                    location: isBreak ? "" : context.state.location,
                    person: isBreak ? "" : context.state.teacher,
                    alignment: .leading
                )

                Spacer(minLength: 0)

                lessonColumn(
                    caption: "Следующая",
                    title: context.state.nextTitle ?? "Нет пары",
                    location: nextDetails.location,
                    person: nextDetails.person,
                    alignment: .trailing
                )
            }

            HStack(alignment: .center, spacing: 10) {
                Text(context.state.startTime, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 48, alignment: .leading)

                lessonProgressView(context: context)

                Text(context.state.endTime, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 48, alignment: .trailing)
            }

            HStack {
                Spacer(minLength: 0)
                Text(context.state.endTime, style: .timer)
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private func islandCurrentColumn(context: ActivityViewContext<ScheduleActivityAttributes>) -> some View {
        let isBreak = context.state.lessonTitle == "Перерыв"

        return VStack(alignment: .leading, spacing: 2) {
            Text(isBreak ? "Перерыв" : context.state.lessonTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if !isBreak {
                Text(context.state.location)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(context.state.teacher)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func islandNextColumn(context: ActivityViewContext<ScheduleActivityAttributes>) -> some View {
        let details = splitNextSubtitle(context.state.nextSubtitle)

        return VStack(alignment: .trailing, spacing: 2) {
            Text(context.state.nextTitle ?? "Нет пары")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if !details.location.isEmpty {
                Text(details.location)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !details.person.isEmpty {
                Text(details.person)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func splitNextSubtitle(_ subtitle: String?) -> (person: String, location: String) {
        guard let subtitle, !subtitle.isEmpty else {
            return ("", "")
        }
        let separator = ", ауд. "
        guard let range = subtitle.range(of: separator) else {
            if subtitle.hasPrefix("ауд. ") {
                return ("", String(subtitle.dropFirst(5)))
            }
            return (subtitle, "")
        }
        let person = String(subtitle[..<range.lowerBound])
        let location = String(subtitle[range.upperBound...])
        return (person, location)
    }

    private func lessonColumn(
        caption: String,
        title: String,
        location: String,
        person: String,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            if !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            if !location.isEmpty {
                Text(location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            if !person.isEmpty {
                Text(person)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
    }

    @ViewBuilder
    private func lessonProgressView(context: ActivityViewContext<ScheduleActivityAttributes>) -> some View {
        if context.state.endTime > context.state.startTime {
            ProgressView(timerInterval: context.state.startTime...context.state.endTime, countsDown: false)
                .progressViewStyle(.linear)
                .tint(activityTint(for: context))
                .labelsHidden()
                .frame(maxWidth: .infinity)
        } else {
            ProgressView(value: context.state.progress)
                .progressViewStyle(.linear)
                .tint(activityTint(for: context))
                .labelsHidden()
                .frame(maxWidth: .infinity)
        }
    }

    private func progressRing(context: ActivityViewContext<ScheduleActivityAttributes>) -> some View {
        ZStack {
            Circle()
                .stroke(activityTint(for: context).opacity(0.24), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(context.state.progress, 0), 1)))
                .stroke(activityTint(for: context), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: context.state.lessonTitle == "Перерыв" ? "pause.fill" : "book.closed.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func activityTint(for context: ActivityViewContext<ScheduleActivityAttributes>) -> Color {
        context.state.lessonTitle == "Перерыв" ? .orange : .blue
    }

    @ViewBuilder
    private func nextEventView(context: ActivityViewContext<ScheduleActivityAttributes>) -> some View {
        if let nextTitle = context.state.nextTitle,
           let nextTime = context.state.nextTime {
            HStack(spacing: 6) {
                Text("Дальше")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(nextTime, style: .time)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(nextTitle)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                if let nextSubtitle = context.state.nextSubtitle, !nextSubtitle.isEmpty {
                    Text(nextSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
