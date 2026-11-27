import AppKit
import Foundation

final class AppRelauncher: @unchecked Sendable {
    typealias LaunchCommand = (_ executableURL: URL, _ arguments: [String]) throws -> Void
    typealias WorkspaceLauncher = (
        _ applicationURL: URL,
        _ completion: @escaping @Sendable (Bool) -> Void
    ) -> Void

    private let launchCommand: LaunchCommand
    private let workspaceLauncher: WorkspaceLauncher

    init(
        launchCommand: @escaping LaunchCommand = AppRelauncher.runProcess,
        workspaceLauncher: @escaping WorkspaceLauncher = AppRelauncher.openNewApplicationInstance
    ) {
        self.launchCommand = launchCommand
        self.workspaceLauncher = workspaceLauncher
    }

    func relaunchAfterTermination(bundlePath: String) {
        let command = "sleep 0.5; /usr/bin/open -n \(shellQuoted(bundlePath))"
        try? launchCommand(URL(fileURLWithPath: "/bin/sh"), ["-c", command])
    }

    @MainActor
    func relaunchAndTerminate(
        bundlePath: String,
        terminate: @escaping @MainActor () -> Void = { NSApp.terminate(nil) }
    ) {
        let bundleURL = URL(fileURLWithPath: bundlePath)
        var didTerminate = false
        let finishOnce: @MainActor () -> Void = {
            guard didTerminate == false else { return }
            didTerminate = true
            terminate()
        }

        workspaceLauncher(bundleURL) { launched in
            Task { @MainActor in
                if launched == false {
                    self.relaunchAfterTermination(bundlePath: bundlePath)
                }
                finishOnce()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            finishOnce()
        }
    }

    private static func openNewApplicationInstance(
        applicationURL: URL,
        completion: @escaping @Sendable (Bool) -> Void
    ) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { app, error in
            completion(app != nil && error == nil)
        }
    }

    private static func runProcess(executableURL: URL, arguments: [String]) throws {
        let task = Process()
        task.executableURL = executableURL
        task.arguments = arguments
        try task.run()
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
