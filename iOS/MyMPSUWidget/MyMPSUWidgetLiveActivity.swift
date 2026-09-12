import ActivityKit
import WidgetKit
import SwiftUI

@available(iOSApplicationExtension 16.1, *)
struct MyMPSULiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var lessonTitle: String
        var teacher: String
        var location: String
        var startTime: Date
        var endTime: Date
        var progress: Double
        var nextTitle: String?
        var nextTime: Date?
        var nextSubtitle: String?
    }

    var groupName: String
}

@available(iOSApplicationExtension 16.1, *)
struct MyMPSUWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MyMPSULiveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Text(context.state.lessonTitle).font(.headline).lineLimit(1)
                Text(context.state.teacher).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                Text(context.state.location).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 8) {
                    Text(context.state.startTime, style: .time).font(.caption).foregroundStyle(.secondary)
                    lessonProgressView(context: context)
                    Text(context.state.endTime, style: .time).font(.caption).foregroundStyle(.secondary)
                }
                nextEventView(context: context)
            }
            .padding(.vertical, 2)
            .activityBackgroundTint(.indigo.opacity(0.18))
            .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text(context.state.startTime, style: .time).font(.caption) }
                DynamicIslandExpandedRegion(.trailing) { Text(context.state.endTime, style: .time).font(.caption) }
                DynamicIslandExpandedRegion(.center) { Text(context.state.lessonTitle).font(.subheadline).lineLimit(1) }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.teacher).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Text(context.state.location).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        lessonProgressView(context: context)
                        nextEventView(context: context)
                    }
                }
            } compactLeading: {
                Text(context.state.startTime, style: .time).font(.caption2)
            } compactTrailing: {
                Text(context.state.endTime, style: .time).font(.caption2)
            } minimal: {
                Image(systemName: "book.closed.fill")
            }
            .widgetURL(URL(string: "mympsu://schedule"))
            .keylineTint(.accentColor)
        }
    }

    @ViewBuilder
    private func lessonProgressView(context: ActivityViewContext<MyMPSULiveActivityAttributes>) -> some View {
        if context.state.endTime > context.state.startTime {
            ProgressView(timerInterval: context.state.startTime...context.state.endTime, countsDown: false)
        } else {
            ProgressView(value: context.state.progress)
        }
    }

    @ViewBuilder
    private func nextEventView(context: ActivityViewContext<MyMPSULiveActivityAttributes>) -> some View {
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
