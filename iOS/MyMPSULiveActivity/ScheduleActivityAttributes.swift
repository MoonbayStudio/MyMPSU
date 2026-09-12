//
//  ScheduleActivityAttributes.swift
//  MyMPSU
//
//  Created by Nicolas Forest on 11/4/25.
//

import ActivityKit
import Foundation

@available(iOSApplicationExtension 16.1, *)
struct ScheduleActivityAttributes: ActivityAttributes {
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
