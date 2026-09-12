import Foundation

struct MyGroup: Identifiable, Codable, Hashable {
    let id: String
    let name: String
}

struct Institute: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let groups: [MyGroup]
}
