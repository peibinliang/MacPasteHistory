import Foundation

protocol RecordingSettingsProviding {
    var shouldRecordText: Bool { get }
    var shouldRecordImage: Bool { get }
}

struct DefaultRecordingSettingsProvider: RecordingSettingsProviding {
    var shouldRecordText: Bool {
        DefaultSettings.shouldRecordText
    }

    var shouldRecordImage: Bool {
        DefaultSettings.shouldRecordImage
    }
}
