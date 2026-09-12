import Foundation

struct ScheduleItem: Identifiable, Codable, Hashable {
    var id: String {
        [
            sortDateISO,
            endDateISO,
            time,
            title,
            teacher,
            room,
            subgroup ?? ""
        ].joined(separator: "|")
    }

    let sortDateISO: String
    let endDateISO: String
    let time: String
    let title: String
    let teacher: String
    let lessonType: String
    let address: String
    let subgroup: String?
    let period: String
    let room: String
    let classURL: String?
}
