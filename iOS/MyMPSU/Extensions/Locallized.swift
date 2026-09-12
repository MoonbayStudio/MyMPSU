import Foundation

extension String {
    var mympsuTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var mympsuNormalizedGroupKey: String {
        mympsuTrimmed
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "№", with: "")
    }
}
