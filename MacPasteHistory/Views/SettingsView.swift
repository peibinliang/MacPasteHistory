import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Recording") {
                Toggle("Record text clipboard history", isOn: .constant(DefaultSettings.shouldRecordText))
                Toggle("Record image clipboard history", isOn: .constant(DefaultSettings.shouldRecordImage))
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(minWidth: 420, minHeight: 320)
    }
}
