import Foundation

enum PelikashaScheduleContextBuilder {
    static func cachedSchedule(from items: [ScheduleItem], date: Date, source: String = "ios-cache") -> CachedSchedulePayload {
        let formatter = ISO8601DateFormatter()
        return CachedSchedulePayload(
            generatedAt: formatter.string(from: Date()),
            source: source,
            lessons: items.map {
                CachedScheduleLessonPayload(
                    name: $0.title,
                    type: $0.lessonType,
                    startTime: $0.sortDateISO,
                    endTime: $0.endDateISO,
                    date: nil,
                    room: $0.room,
                    teacher: $0.teacher,
                    classUrl: $0.classURL,
                    isExam: !$0.period.mympsuTrimmed.isEmpty
                )
            }
        )
    }
}
