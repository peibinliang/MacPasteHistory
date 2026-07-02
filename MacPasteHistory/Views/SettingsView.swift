import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showClearConfirmation = false

    var body: some View {
        Form {
            recordingSection
            retentionSection
            limitsSection
            storageSection
            dataSection
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(minWidth: 460, minHeight: 480)
        .onAppear { viewModel.loadSettings() }
        .alert("Clear All Data?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                viewModel.clearAllData()
            }
        } message: {
            Text("This will permanently delete all clipboard history records and image files. This action cannot be undone.")
        }
    }

    // MARK: - Sections

    private var recordingSection: some View {
        Section("Recording") {
            Toggle("Record text clipboard history", isOn: $viewModel.shouldRecordText)
                .onChange(of: viewModel.shouldRecordText) { _, newValue in
                    viewModel.updateShouldRecordText(newValue)
                }
            Toggle("Record image clipboard history", isOn: $viewModel.shouldRecordImage)
                .onChange(of: viewModel.shouldRecordImage) { _, newValue in
                    viewModel.updateShouldRecordImage(newValue)
                }
            Toggle("Launch at login", isOn: $viewModel.launchAtStartup)
                .onChange(of: viewModel.launchAtStartup) { _, newValue in
                    viewModel.updateLaunchAtStartup(newValue)
                }
            Toggle("Show Dock icon", isOn: $viewModel.showDockIcon)
                .onChange(of: viewModel.showDockIcon) { _, newValue in
                    viewModel.updateShowDockIcon(newValue)
                }
        }
    }

    private var retentionSection: some View {
        Section("History Retention") {
            Stepper(
                "Keep history for \(viewModel.historyRetentionDays) days",
                value: $viewModel.historyRetentionDays,
                in: 1...365
            )
            .onChange(of: viewModel.historyRetentionDays) { _, newValue in
                viewModel.updateHistoryRetentionDays(newValue)
            }
        }
    }

    private var limitsSection: some View {
        Section("Record Limits") {
            Stepper(
                "Maximum \(viewModel.maxTextHistoryCount) text records",
                value: $viewModel.maxTextHistoryCount,
                in: 100...5_000,
                step: 100
            )
            .onChange(of: viewModel.maxTextHistoryCount) { _, newValue in
                viewModel.updateMaxTextHistoryCount(newValue)
            }
            Stepper(
                "Maximum \(viewModel.maxImageHistoryCount) image records",
                value: $viewModel.maxImageHistoryCount,
                in: 10...500,
                step: 10
            )
            .onChange(of: viewModel.maxImageHistoryCount) { _, newValue in
                viewModel.updateMaxImageHistoryCount(newValue)
            }
        }
    }

    private var storageSection: some View {
        Section("Storage") {
            Picker("Single image size limit", selection: $viewModel.singleImageSizeLimit) {
                Text("5 MB").tag(5)
                Text("10 MB").tag(10)
                Text("20 MB").tag(20)
                Text("50 MB").tag(50)
            }
            .onChange(of: viewModel.singleImageSizeLimit) { _, newValue in
                viewModel.updateSingleImageSizeLimit(newValue)
            }
            Picker("Total storage cap", selection: $viewModel.totalStorageCap) {
                Text("100 MB").tag(100)
                Text("250 MB").tag(250)
                Text("500 MB").tag(500)
                Text("1 GB").tag(1_000)
            }
            .onChange(of: viewModel.totalStorageCap) { _, newValue in
                viewModel.updateTotalStorageCap(newValue)
            }
        }
    }

    private var dataSection: some View {
        Section("Data Management") {
            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Label("Clear All Data", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        }
    }
}
