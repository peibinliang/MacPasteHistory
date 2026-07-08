import Foundation

final class AppRelauncher {
    typealias LaunchCommand = (_ executableURL: URL, _ arguments: [String]) throws -> Void

    private let launchCommand: LaunchCommand

    init(launchCommand: @escaping LaunchCommand = AppRelauncher.runProcess) {
        self.launchCommand = launchCommand
    }

    func relaunchAfterTermination(bundlePath: String) {
        let command = "sleep 0.5; /usr/bin/open -n \(shellQuoted(bundlePath))"
        try? launchCommand(URL(fileURLWithPath: "/bin/sh"), ["-c", command])
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
