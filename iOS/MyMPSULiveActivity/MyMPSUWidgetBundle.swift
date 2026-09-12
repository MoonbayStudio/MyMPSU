import WidgetKit
import SwiftUI

@main
struct MyMPSUWidgetBundle: WidgetBundle {
    var body: some Widget {
        MyMPSULiveActivity()

        if #available(iOSApplicationExtension 16.1, *) {
            ScheduleActivityLiveActivity()
        }
    }
}
